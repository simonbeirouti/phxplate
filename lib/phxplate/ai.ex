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
  def create_conversation(user_id, title, system_prompt \\ @default_system_prompt) do
    %Conversation{}
    |> Conversation.changeset(%{
      title: title,
      system_prompt: system_prompt,
      user_id: user_id
    })
    |> Repo.insert()
  end

  @doc """
  Gets a conversation by ID, ensuring it belongs to the specified user.
  """
  def get_conversation(conversation_id, user_id) do
    Conversation
    |> where([c], c.id == ^conversation_id and c.user_id == ^user_id)
    |> preload(:messages)
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

  # ============================================================================
  # Message Management
  # ============================================================================

  @doc """
  Adds a message to a conversation.
  """
  def add_message(conversation_id, role, content, model \\ nil, metadata \\ %{}) do
    %Message{}
    |> Message.changeset(%{
      conversation_id: conversation_id,
      role: role,
      content: content,
      model: model,
      metadata: metadata
    })
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
  def stream_chat_in_conversation(conversation_id, user_id, user_message, model_api_id) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        # Add user message to conversation (no model for user messages)
        {:ok, _user_message} = add_message(conversation_id, "user", user_message)

        # Get all messages for context
        messages = get_conversation_messages(conversation_id)
        anthropix_messages = messages_to_anthropix_format(messages)

        # Stream AI response using the specified model
        case Anthropix.chat(client(),
               model: model_api_id,
               max_tokens: 4000,
               system: conversation.system_prompt,
               messages: anthropix_messages ++ [%{role: "user", content: user_message}],
               stream: true
             ) do
          {:ok, stream} ->
            {:ok, stream, conversation, model_api_id}
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
  def complete_streaming_conversation(conversation_id, ai_response, model_api_id) do
    {:ok, ai_message} = add_message(conversation_id, :assistant, ai_response, model_api_id)

    # Update conversation timestamp (truncate to seconds for Ecto compatibility)
    conversation = Repo.get!(Conversation, conversation_id)
    Repo.update!(Ecto.Changeset.change(conversation, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)))

    {:ok, ai_message}
  end

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
  Run an evaluation against a specific model and optional prompt.
  """
  def run_evaluation(eval_id, model, user_id, prompt_id \\ nil) do
    with {:ok, eval} <- get_eval_for_run(eval_id),
         {:ok, eval_run} <- create_eval_run(%{
           eval_id: eval_id,
           prompt_id: prompt_id,
           model: model,
           run_by: user_id,
           status: "pending"
         }) do

      # Start the evaluation run in a background task
      Task.start(fn ->
        execute_evaluation(eval_run.id, eval, model, prompt_id)
      end)

      {:ok, eval_run}
    end
  end

  defp get_eval_for_run(eval_id) do
    case get_eval(eval_id) do
      nil -> {:error, :eval_not_found}
      eval -> {:ok, eval}
    end
  end

  defp execute_evaluation(eval_run_id, eval, model, prompt_id) do
    eval_run = Repo.get!(EvalRun, eval_run_id)

    # Mark as running
    {:ok, eval_run} = eval_run
      |> EvalRun.start_changeset()
      |> Repo.update()

    try do
      # Get the prompt if specified
      system_prompt = if prompt_id do
        case get_prompt(prompt_id) do
          nil -> @default_system_prompt
          prompt -> prompt.content
        end
      else
        @default_system_prompt
      end

      # Run each test case
      results = eval.test_cases
        |> Enum.map(fn {test_name, test_input} ->
          case chat(test_input, system_prompt, model) do
            {:ok, response} ->
              expected = Map.get(eval.expected_outputs, test_name, "")
              score = calculate_similarity_score(response, expected)

              {test_name, %{
                input: test_input,
                output: response,
                expected: expected,
                score: score,
                passed: score >= 0.7  # Threshold for passing
              }}

            {:error, error} ->
              {test_name, %{
                input: test_input,
                output: "",
                expected: Map.get(eval.expected_outputs, test_name, ""),
                score: 0.0,
                passed: false,
                error: inspect(error)
              }}
          end
        end)
        |> Enum.into(%{})

      # Calculate overall score
      scores = results
        |> Enum.map(fn {_name, result} -> Map.get(result, :score, 0.0) end)

      overall_score = if Enum.empty?(scores) do
        0.0
      else
        Enum.sum(scores) / length(scores)
      end

      # Mark as completed
      eval_run
      |> EvalRun.complete_changeset(results, overall_score)
      |> Repo.update()

    rescue
      error ->
        # Mark as failed
        eval_run
        |> EvalRun.fail_changeset(inspect(error))
        |> Repo.update()
    end
  end

  # Simple similarity scoring - in a real implementation you might want
  # to use more sophisticated methods like semantic similarity
  defp calculate_similarity_score(actual, expected) when is_binary(actual) and is_binary(expected) do
    actual_words = String.split(String.downcase(actual))
    expected_words = String.split(String.downcase(expected))

    if Enum.empty?(expected_words) do
      1.0
    else
      common_words = MapSet.intersection(MapSet.new(actual_words), MapSet.new(expected_words))
      MapSet.size(common_words) / length(expected_words)
    end
  end

  defp calculate_similarity_score(_, _), do: 0.0
end
