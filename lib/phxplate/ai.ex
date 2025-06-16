defmodule Phxplate.AI do
  @moduledoc """
  AI module for interacting with Anthropic Claude using the Anthropix library.
  """

  import Ecto.Query
  alias Phxplate.Repo
  alias Phxplate.AI.{Conversation, Message, Prompt, Eval, EvalRun, Models}

  @default_system_prompt """
  You are a helpful AI assistant integrated into a Phoenix application.
  You provide clear, concise, and accurate responses while maintaining a professional tone.
  When discussing code or technical topics, you provide practical examples and explanations.
  """

  @doc """
  Initialize an Anthropix client using the configured API key.
  """
  def client do
    case Application.get_env(:anthropix, :api_key) do
      nil ->
        raise "ANTHROPIC_API_KEY environment variable is not set. Please set it in your environment or config."
      api_key when is_binary(api_key) and api_key != "" ->
        Anthropix.init(api_key)
      _ ->
        raise "Invalid ANTHROPIC_API_KEY. Please check your environment variable."
    end
  end

  # ============================================================================
  # Conversation Management
  # ============================================================================

  @doc """
  Create a new conversation for a user.
  """
  def create_conversation(user_id, title, system_prompt \\ @default_system_prompt, advanced_params \\ %{}) do
    attrs = %{
      title: title,
      system_prompt: system_prompt,
      user_id: user_id
    }
    |> Map.merge(advanced_params)

    %Conversation{}
    |> Conversation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a conversation by ID, ensuring it belongs to the specified user.
  """
  def get_conversation(conversation_id, user_id) do
    Conversation
    |> where([c], c.id == ^conversation_id and c.user_id == ^user_id)
    |> preload([:messages, :selected_prompt, :selected_eval])
    |> Repo.one()
  end

  @doc """
  Lists all conversations for a user, ordered by most recent first.
  """
  def list_conversations(user_id) do
    Conversation
    |> where([c], c.user_id == ^user_id and c.archived == false)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  @doc """
  Returns the total count of conversations.
  """
  def count_conversations do
    try do
      Repo.aggregate(Conversation, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  Returns the total count of conversations with optional filtering.

  ## Options

    * `:archived` - Filter by archived status (true/false)
    * `:user_id` - Filter by specific user
  """
  def count_conversations(opts) do
    try do
      archived = Keyword.get(opts, :archived)
      user_id = Keyword.get(opts, :user_id)

      query = Conversation

      query = if archived != nil do
        where(query, [c], c.archived == ^archived)
      else
        query
      end

      query = if user_id do
        where(query, [c], c.user_id == ^user_id)
      else
        query
      end

      Repo.aggregate(query, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  Update a conversation's title.
  """
  def update_conversation_title(conversation_id, user_id, title) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :not_found}
      conversation ->
        conversation
        |> Conversation.changeset(%{title: title})
        |> Repo.update()
    end
  end

  @doc """
  Auto-generate a title for a conversation based on the first user message.
  """
  def auto_generate_conversation_title(conversation_id, user_id, first_message) do
    title_prompt = """
    Based on this user message, generate a short, descriptive title (3-6 words max) for a chat conversation.
    The title should capture the main topic or intent. Respond with ONLY the title, no quotes or extra text.

    User message: #{first_message}
    """

    case chat(title_prompt, "You are a helpful assistant that creates concise, descriptive titles.", "claude-3-5-haiku-20241022") do
      {:ok, generated_title} ->
        # Clean up the title (remove quotes, trim, limit length)
        clean_title = generated_title
          |> String.trim()
          |> String.replace(~r/^["']|["']$/, "")  # Remove surrounding quotes
          |> String.slice(0, 50)  # Limit to 50 characters

        update_conversation_title(conversation_id, user_id, clean_title)

      {:error, _reason} ->
        # If auto-generation fails, use a fallback based on the first few words
        fallback_title = first_message
          |> String.split()
          |> Enum.take(4)
          |> Enum.join(" ")
          |> String.slice(0, 30)

        update_conversation_title(conversation_id, user_id, fallback_title)
    end
  end

  @doc """
  Archives a conversation.
  """
  def archive_conversation(conversation_id, user_id) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        conversation
        |> Conversation.archive_changeset(true)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a conversation and all its messages.
  """
  def delete_conversation(conversation_id, user_id) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        Repo.delete(conversation)
    end
  end

  @doc """
  Update a conversation's advanced AI parameters.
  """
  def update_conversation_advanced_params(conversation_id, user_id, advanced_params) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        conversation
        |> Conversation.advanced_params_changeset(advanced_params)
        |> Repo.update()
    end
  end

  @doc """
  Update a conversation's prompt and eval settings.
  """
  def update_conversation_prompt_eval(conversation_id, user_id, prompt_eval_params) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        conversation
        |> Conversation.prompt_eval_changeset(prompt_eval_params)
        |> Repo.update()
    end
  end

  # ============================================================================
  # Message Management
  # ============================================================================

  @doc """
  Adds a message to a conversation.
  """
  def add_message(conversation_id, role, content, model \\ nil, metadata \\ %{}, message_params \\ %{}) do
    attrs = %{
      conversation_id: conversation_id,
      role: role,
      content: content,
      model: model,
      metadata: metadata
    }
    |> Map.merge(message_params)

    %Message{}
    |> Message.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets all messages for a conversation, ordered by creation time.
  """
  def get_conversation_messages(conversation_id) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> order_by([m], asc: m.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the total count of AI messages.
  """
  def count_messages do
    try do
      Repo.aggregate(Message, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  Returns the total count of AI messages with optional filtering.

  ## Options

    * `:role` - Filter by message role (:user, :assistant, :system)
    * `:conversation_id` - Filter by specific conversation
  """
  def count_messages(opts) do
    try do
      role = Keyword.get(opts, :role)
      conversation_id = Keyword.get(opts, :conversation_id)

      query = Message

      query = if role do
        where(query, [m], m.role == ^role)
      else
        query
      end

      query = if conversation_id do
        where(query, [m], m.conversation_id == ^conversation_id)
      else
        query
      end

      Repo.aggregate(query, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  Gets the latest prompt and eval settings from the last message in a conversation.
  Returns a map with prompt_name and eval_name, or nil if no messages exist.
  """
  def get_latest_prompt_eval_from_messages(conversation_id) do
    Message
    |> where([m], m.conversation_id == ^conversation_id)
    |> where([m], not is_nil(m.prompt_name) or not is_nil(m.eval_name))
    |> order_by([m], desc: m.inserted_at)
    |> limit(1)
    |> select([m], %{prompt_name: m.prompt_name, eval_name: m.eval_name})
    |> Repo.one()
  end

  @doc """
  Converts messages from the database format to the format expected by Anthropix.
  """
  def messages_to_anthropix_format(messages) do
    messages
    |> Enum.filter(&(&1.role in [:user, :assistant]))
    |> Enum.map(&%{role: Atom.to_string(&1.role), content: &1.content})
  end

  # ============================================================================
  # AI Chat Functions (with persistence)
  # ============================================================================

  @doc """
  Stream chat completion for a conversation using the specified model.
  """
  def stream_chat_in_conversation(conversation_id, user_id, user_message, model_api_id, opts \\ %{}) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        # Add user message to conversation (no model for user messages)
        {:ok, _user_message} = add_message(conversation_id, "user", user_message)

        # Get all messages for context
        messages = get_conversation_messages(conversation_id)
        anthropix_messages = messages_to_anthropix_format(messages)

        # Build chat parameters with defaults
        chat_params = build_chat_params(model_api_id, conversation.system_prompt,
                                       anthropix_messages ++ [%{role: "user", content: user_message}],
                                       opts)

        # Stream AI response using the specified model
        case Anthropix.chat(client(), chat_params) do
          {:ok, stream} ->
            {:ok, stream, conversation, model_api_id, opts}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Chat with AI in a conversation context using the conversation's model.
  """
  def chat_in_conversation(conversation_id, user_id, user_message) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        # Add user message to conversation
        {:ok, _user_message} = add_message(conversation_id, "user", user_message)

        # Get all messages for context
        messages = get_conversation_messages(conversation_id)
        anthropix_messages = messages_to_anthropix_format(messages)

        # Use the conversation's model
        model = conversation.model || Models.default_model_api_id()

                 # Get AI response using the conversation's model
         case Anthropix.chat(client(),
               model: model,
               max_tokens: 4000,
               system: conversation.system_prompt,
               messages: anthropix_messages ++ [%{role: "user", content: user_message}]
             ) do
          {:ok, %{content: [%{text: ai_response}]}} ->
            # Save AI response
            case add_message(conversation_id, "assistant", ai_response) do
              {:ok, _ai_msg} -> {:ok, ai_response, conversation}
              error -> error
            end

          error -> error
        end
    end
  end

  @doc """
  Completes a streaming conversation by saving the final AI response with the model used.
  """
  def complete_streaming_conversation(conversation_id, ai_response, model_api_id, opts \\ %{}) do
    # Extract active advanced parameters for the message
    active_params = extract_active_advanced_params(opts)

    # Include prompt and eval information
    prompt_eval_params = %{
      prompt_id: opts[:prompt_id],
      eval_id: opts[:eval_id]
    }

    # Merge all message parameters
    message_params = Map.merge(active_params, prompt_eval_params)

    # Include advanced parameters in metadata for backward compatibility
    metadata = Map.take(opts, [:max_tokens, :temperature, :top_k, :top_p])

    {:ok, ai_message} = add_message(conversation_id, :assistant, ai_response, model_api_id, metadata, message_params)

    # Update conversation timestamp (truncate to seconds for Ecto compatibility)
    conversation = Repo.get!(Conversation, conversation_id)
    Repo.update!(Ecto.Changeset.change(conversation, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)))

    {:ok, ai_message}
  end

  defp build_chat_params(model_api_id, system_prompt, messages, opts) do
    base_params = %{
      model: model_api_id,
      system: system_prompt,
      messages: messages,
      stream: true
    }

    # Add advanced parameters if they are provided and active
    base_params
    |> maybe_add_param(:max_tokens, opts[:max_tokens], opts[:max_tokens_active])
    |> maybe_add_param(:temperature, opts[:temperature], opts[:temperature_active])
    |> maybe_add_param(:top_k, opts[:top_k], opts[:top_k_active])
    |> maybe_add_param(:top_p, opts[:top_p], opts[:top_p_active])
  end

  defp maybe_add_param(params, _key, _value, false), do: params
  defp maybe_add_param(params, _key, nil, _active), do: params
  defp maybe_add_param(params, key, value, true), do: Map.put(params, key, value)

  # Helper function to extract only active advanced parameters
  defp extract_active_advanced_params(opts) do
    %{}
    |> maybe_add_active_param(:max_tokens, opts[:max_tokens], opts[:max_tokens_active])
    |> maybe_add_active_param(:temperature, opts[:temperature], opts[:temperature_active])
    |> maybe_add_active_param(:top_k, opts[:top_k], opts[:top_k_active])
    |> maybe_add_active_param(:top_p, opts[:top_p], opts[:top_p_active])
  end

  defp maybe_add_active_param(params, _key, _value, false), do: params
  defp maybe_add_active_param(params, _key, nil, _active), do: params
  defp maybe_add_active_param(params, key, value, true), do: Map.put(params, key, value)

  # ============================================================================
  # Legacy Functions (for backward compatibility)
  # ============================================================================

  @doc """
  Send a simple text message to Claude and get a response.
  Optionally accepts a system prompt to guide the response.

  ## Examples

      iex> Phxplate.AI.chat("Hello, how are you?")
      {:ok, "Hello! I'm doing well, thank you for asking..."}

      iex> Phxplate.AI.chat("What is the capital of France?", "You are a geography expert.")
      {:ok, "The capital of France is Paris."}
  """
  def chat(message, system_prompt \\ @default_system_prompt, model \\ nil) when is_binary(message) do
    model = model || Models.default_model_api_id()
    messages = [%{role: "user", content: message}]

    case Anthropix.chat(client(),
      model: model,
      messages: messages,
      system: system_prompt
    ) do
      {:ok, %{"content" => [%{"text" => text}]}} -> {:ok, text}
      {:ok, response} -> {:ok, extract_text_from_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a conversation (list of messages) to Claude.
  Optionally accepts a system prompt to guide the response.

  ## Examples

      messages = [
        %{role: "user", content: "What is 2+2?"},
        %{role: "assistant", content: "2+2 equals 4."},
        %{role: "user", content: "What about 3+3?"}
      ]

      Phxplate.AI.chat_conversation(messages, "You are a math tutor.")
  """
  def chat_conversation(messages, system_prompt \\ @default_system_prompt, model \\ nil) when is_list(messages) do
    model = model || Models.default_model_api_id()
    case Anthropix.chat(client(),
      model: model,
      messages: messages,
      system: system_prompt
    ) do
      {:ok, %{"content" => [%{"text" => text}]}} -> {:ok, text}
      {:ok, response} -> {:ok, extract_text_from_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a message to Claude with a system prompt.
  This is an alias for chat/2 for backward compatibility.

  ## Examples

      Phxplate.AI.chat_with_system(
        "You are a helpful coding assistant.",
        "How do I create a Phoenix LiveView component?"
      )
  """
  def chat_with_system(system_prompt, user_message, model \\ nil) do
    model = model || Models.default_model_api_id()
    chat(user_message, system_prompt, model)
  end

  @doc """
  Stream a conversation with Claude for real-time responses.
  Optionally accepts a system prompt to guide the response.

  ## Examples

      {:ok, stream} = Phxplate.AI.stream_chat("Tell me a story", "You are a creative storyteller.")

      stream
      |> Stream.each(fn chunk ->
        # Process each chunk of the response
        IO.puts(chunk)
      end)
      |> Stream.run()
  """
  def stream_chat(message, system_prompt \\ @default_system_prompt, model \\ nil) when is_binary(message) do
    model = model || Models.default_model_api_id()
    messages = [%{role: "user", content: message}]

    case Anthropix.chat(client(),
      model: model,
      messages: messages,
      system: system_prompt,
      stream: true
    ) do
      {:ok, stream} ->
        {:ok, Stream.map(stream, &extract_text_from_stream/1)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Helper function to extract text from stream chunks
  def extract_text_from_stream(%{"type" => "content_block_delta", "delta" => %{"text" => text}}) do
    text
  end
  def extract_text_from_stream(%{"type" => "message_delta", "delta" => %{"content" => [%{"text" => text}]}}) do
    text
  end
  def extract_text_from_stream(_), do: ""

  # Private helper function to extract text from various response formats
  defp extract_text_from_response(%{"content" => content}) when is_list(content) do
    content
    |> Enum.find_value("", fn
      %{"type" => "text", "text" => text} -> text
      _ -> nil
    end)
  end

  defp extract_text_from_response(response) do
    inspect(response)
  end

  # ============================================================================
  # Prompt Management
  # ============================================================================

  @doc """
  Create a new AI prompt.
  """
  def create_prompt(attrs) do
    %Prompt{}
    |> Prompt.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get a prompt by ID.
  """
  def get_prompt(id) do
    Repo.get(Prompt, id)
  end

  @doc """
  Get a prompt by ID with preloaded associations.
  """
  def get_prompt_with_creator(id) do
    Prompt
    |> where([p], p.id == ^id)
    |> preload(:created_by_user)
    |> Repo.one()
  end

  @doc """
  List all active prompts.
  """
  def list_prompts do
    Prompt
    |> where([p], p.is_active == true)
    |> order_by([p], desc: p.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the total count of AI prompts.
  """
  def count_prompts do
    try do
      Repo.aggregate(Prompt, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  Returns the total count of AI prompts with optional filtering.

  ## Options

    * `:is_active` - Filter by active status (true/false)
    * `:category` - Filter by category
  """
  def count_prompts(opts) do
    try do
      is_active = Keyword.get(opts, :is_active)
      category = Keyword.get(opts, :category)

      query = Prompt

      query = if is_active != nil do
        where(query, [p], p.is_active == ^is_active)
      else
        query
      end

      query = if category do
        where(query, [p], p.category == ^category)
      else
        query
      end

      Repo.aggregate(query, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  List prompts with pagination and optional filtering.
  """
  def list_prompts(page, per_page, opts \\ []) do
    category = Keyword.get(opts, :category)
    search = Keyword.get(opts, :search)

    query = from p in Prompt,
      order_by: [desc: p.inserted_at],
      preload: [:created_by_user]

    query = if category && category != "all" do
      where(query, [p], p.category == ^category)
    else
      query
    end

    query = if search && String.trim(search) != "" do
      search_term = "%#{String.trim(search)}%"
      where(query, [p], ilike(p.name, ^search_term) or ilike(p.description, ^search_term))
    else
      query
    end

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)

    prompts = query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      prompts: prompts,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Update a prompt.
  """
  def update_prompt(prompt, attrs) do
    prompt
    |> Prompt.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete a prompt.
  """
  def delete_prompt(prompt) do
    Repo.delete(prompt)
  end

  @doc """
  List prompts by category.
  """
  def list_prompts_by_category(category) do
    Prompt
    |> where([p], p.category == ^category and p.is_active == true)
    |> order_by([p], asc: p.name)
    |> Repo.all()
  end

  @doc """
  Get the default system prompt from the database.
  Falls back to the hardcoded default if no system prompts exist.
  """
  def get_default_system_prompt do
    case list_prompts_by_category("system") do
      [] -> @default_system_prompt
      [first_prompt | _] -> first_prompt.content
    end
  end

  @doc """
  List all active system prompts.
  """
  def list_system_prompts do
    list_prompts_by_category("system")
  end

  @doc """
  List all active prompts for chat interface.
  Includes error handling for when tables don't exist.
  """
  def list_prompts_for_chat do
    try do
      Prompt
      |> where([p], p.is_active == true)
      |> order_by([p], asc: p.name)
      |> Repo.all()
    rescue
      _ -> []
    end
  end

  # ============================================================================
  # Evaluation Management
  # ============================================================================

  @doc """
  Create a new AI evaluation.
  """
  def create_eval(attrs) do
    %Eval{}
    |> Eval.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get an evaluation by ID.
  """
  def get_eval(id) do
    Repo.get(Eval, id)
  end

  @doc """
  Get an evaluation by ID with preloaded associations.
  """
  def get_eval_with_creator(id) do
    Eval
    |> where([e], e.id == ^id)
    |> preload([:created_by_user, :eval_runs])
    |> Repo.one()
  end

  @doc """
  List all active evaluations.
  """
  def list_evals do
    Eval
    |> where([e], e.is_active == true)
    |> order_by([e], desc: e.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the total count of AI evaluations.
  """
  def count_evals do
    try do
      Repo.aggregate(Eval, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  Returns the total count of AI evaluations with optional filtering.

  ## Options

    * `:is_active` - Filter by active status (true/false)
  """
  def count_evals(opts) do
    try do
      is_active = Keyword.get(opts, :is_active)

      query = Eval

      query = if is_active != nil do
        where(query, [e], e.is_active == ^is_active)
      else
        query
      end

      Repo.aggregate(query, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  List evaluations with pagination and optional filtering.
  """
  def list_evals(page, per_page, opts \\ []) do
    search = Keyword.get(opts, :search)
    status = Keyword.get(opts, :status, "all")

    query = from e in Eval,
      order_by: [desc: e.inserted_at],
      preload: [:created_by_user]

    query = if search && String.trim(search) != "" do
      search_term = "%#{String.trim(search)}%"
      where(query, [e], ilike(e.name, ^search_term) or ilike(e.description, ^search_term))
    else
      query
    end

    query = case status do
      "active" -> where(query, [e], e.is_active == true)
      "inactive" -> where(query, [e], e.is_active == false)
      _ -> query  # "all" or any other value shows all
    end

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)

    evals = query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      evals: evals,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Update an evaluation.
  """
  def update_eval(eval, attrs) do
    eval
    |> Eval.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Delete an evaluation.
  """
  def delete_eval(eval) do
    Repo.delete(eval)
  end

  # ============================================================================
  # Evaluation Run Management
  # ============================================================================

  @doc """
  Create a new evaluation run.
  """
  def create_eval_run(attrs) do
    %EvalRun{}
    |> EvalRun.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Get an evaluation run by ID.
  """
  def get_eval_run(id) do
    EvalRun
    |> where([er], er.id == ^id)
    |> preload([:eval, :prompt, :run_by_user])
    |> Repo.one()
  end

  @doc """
  List evaluation runs for a specific evaluation.
  """
  def list_eval_runs(eval_id) do
    EvalRun
    |> where([er], er.eval_id == ^eval_id)
    |> order_by([er], desc: er.inserted_at)
    |> preload([:prompt, :run_by_user])
    |> Repo.all()
  end

  @doc """
  Returns the total count of evaluation runs.
  """
  def count_eval_runs do
    try do
      Repo.aggregate(EvalRun, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  Returns the total count of evaluation runs with optional filtering.

  ## Options

    * `:status` - Filter by status ("pending", "running", "completed", "failed")
    * `:eval_id` - Filter by specific evaluation
  """
  def count_eval_runs(opts) do
    try do
      status = Keyword.get(opts, :status)
      eval_id = Keyword.get(opts, :eval_id)

      query = EvalRun

      query = if status do
        where(query, [er], er.status == ^status)
      else
        query
      end

      query = if eval_id do
        where(query, [er], er.eval_id == ^eval_id)
      else
        query
      end

      Repo.aggregate(query, :count, :id)
    rescue
      _ -> 0
    end
  end

  @doc """
  List all evaluation runs with pagination and optional filtering.
  """
  def list_all_eval_runs(page, per_page, opts \\ []) do
    status = Keyword.get(opts, :status, "all")
    eval_id = Keyword.get(opts, :eval_id)
    prompt_id = Keyword.get(opts, :prompt_id)

    query = from er in EvalRun,
      order_by: [desc: er.inserted_at],
      preload: [:eval, :prompt, :run_by_user]

    query = case status do
      "completed" -> where(query, [er], er.status == "completed")
      "failed" -> where(query, [er], er.status == "failed")
      "running" -> where(query, [er], er.status == "running")
      "pending" -> where(query, [er], er.status == "pending")
      _ -> query  # "all" or any other value shows all
    end

    query = if eval_id do
      where(query, [er], er.eval_id == ^eval_id)
    else
      query
    end

    query = if prompt_id do
      where(query, [er], er.prompt_id == ^prompt_id)
    else
      query
    end

    total_count = Repo.aggregate(query, :count, :id)
    total_pages = ceil(total_count / per_page)

    eval_runs = query
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{
      eval_runs: eval_runs,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  @doc """
  Delete an evaluation run.
  """
  def delete_eval_run(eval_run_id) do
    case get_eval_run(eval_run_id) do
      nil -> {:error, :eval_run_not_found}
      eval_run -> Repo.delete(eval_run)
    end
  end

  @doc """
  Run an evaluation against a specific model and optional prompt.
  Now uses the evaluation queue for rate limiting.
  """
  def run_evaluation(eval_id, model, user_id, prompt_id \\ nil) do
    with {:ok, _eval} <- get_eval_for_run(eval_id),
         {:ok, eval_run} <- create_eval_run(%{
           eval_id: eval_id,
           prompt_id: prompt_id,
           model: model,
           run_by: user_id,
           status: "pending"
         }) do

      # Add to the evaluation queue instead of starting directly
      case Phxplate.AI.EvaluationQueue.enqueue(eval_run.id) do
        {:ok, queue_position} ->
          require Logger
          Logger.info("📥 Evaluation #{eval_run.id} added to queue at position #{queue_position}")
          {:ok, eval_run}
        {:error, reason} ->
          require Logger
          Logger.error("❌ Failed to enqueue evaluation #{eval_run.id}: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp get_eval_for_run(eval_id) do
    case get_eval(eval_id) do
      nil -> {:error, :eval_not_found}
      eval -> {:ok, eval}
    end
  end

end
