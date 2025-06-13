defmodule Phxplate.AI do
  @moduledoc """
  AI module for interacting with Anthropic Claude using the Anthropix library.
  """

  import Ecto.Query
  alias Phxplate.Repo
  alias Phxplate.AI.{Conversation, Message}

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
  Creates a new conversation for a user.
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
  def list_conversations(user_id, opts \\ []) do
    archived = Keyword.get(opts, :archived, false)

    Conversation
    |> where([c], c.user_id == ^user_id and c.archived == ^archived)
    |> order_by([c], desc: c.updated_at)
    |> Repo.all()
  end

  @doc """
  Updates a conversation's title.
  """
  def update_conversation_title(conversation_id, user_id, new_title) do
    case get_conversation(conversation_id, user_id) do
      nil -> {:error, :not_found}
      conversation ->
        conversation
        |> Conversation.title_changeset(%{title: new_title})
        |> Repo.update()
    end
  end

  @doc """
  Archives or unarchives a conversation.
  """
  def archive_conversation(conversation_id, user_id, archived \\ true) do
    case get_conversation(conversation_id, user_id) do
      nil -> {:error, :not_found}
      conversation ->
        conversation
        |> Conversation.archive_changeset(archived)
        |> Repo.update()
    end
  end

  @doc """
  Deletes a conversation and all its messages.
  """
  def delete_conversation(conversation_id, user_id) do
    case get_conversation(conversation_id, user_id) do
      nil -> {:error, :not_found}
      conversation -> Repo.delete(conversation)
    end
  end

  # ============================================================================
  # Message Management
  # ============================================================================

  @doc """
  Adds a message to a conversation.
  """
  def add_message(conversation_id, role, content, metadata \\ %{}) do
    %Message{}
    |> Message.changeset(%{
      role: role,
      content: content,
      metadata: metadata,
      conversation_id: conversation_id
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
  Send a message in a conversation and get a response, persisting both messages.
  """
  def chat_in_conversation(conversation_id, user_id, message) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        # Add user message to conversation
        {:ok, _user_message} = add_message(conversation_id, :user, message)

        # Get all messages for context
        messages = get_conversation_messages(conversation_id)
        anthropix_messages = messages_to_anthropix_format(messages)

        # Get AI response
        case Anthropix.chat(client(),
          model: "claude-3-haiku-20240307",
          messages: anthropix_messages,
          system: conversation.system_prompt || @default_system_prompt
        ) do
                    {:ok, %{"content" => [%{"text" => text}]}} ->
            # Add AI response to conversation
            {:ok, ai_message} = add_message(conversation_id, :assistant, text)

            # Update conversation timestamp
            Repo.update!(Ecto.Changeset.change(conversation, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)))

            {:ok, text, ai_message}
          {:ok, response} ->
            text = extract_text_from_response(response)
            {:ok, ai_message} = add_message(conversation_id, :assistant, text)
            Repo.update!(Ecto.Changeset.change(conversation, updated_at: DateTime.utc_now() |> DateTime.truncate(:second)))
            {:ok, text, ai_message}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Stream a conversation with Claude for real-time responses, persisting messages.
  """
  def stream_chat_in_conversation(conversation_id, user_id, message) do
    case get_conversation(conversation_id, user_id) do
      nil ->
        {:error, :conversation_not_found}
      conversation ->
        # Add user message to conversation
        {:ok, _user_message} = add_message(conversation_id, :user, message)

        # Get all messages for context
        messages = get_conversation_messages(conversation_id)
        anthropix_messages = messages_to_anthropix_format(messages)

        # Stream AI response
        case Anthropix.chat(client(),
          model: "claude-3-haiku-20240307",
          messages: anthropix_messages,
          system: conversation.system_prompt || @default_system_prompt,
          stream: true
        ) do
          {:ok, stream} ->
            {:ok, stream, conversation}
          {:error, reason} ->
            {:error, reason}
        end
    end
  end

    @doc """
  Completes a streaming conversation by saving the final AI response.
  """
  def complete_streaming_conversation(conversation_id, ai_response) do
    {:ok, ai_message} = add_message(conversation_id, :assistant, ai_response)

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
  def chat(message, system_prompt \\ @default_system_prompt) when is_binary(message) do
    messages = [%{role: "user", content: message}]

    case Anthropix.chat(client(),
      model: "claude-3-haiku-20240307",
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
  def chat_conversation(messages, system_prompt \\ @default_system_prompt) when is_list(messages) do
    case Anthropix.chat(client(),
      model: "claude-3-haiku-20240307",
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
  def chat_with_system(system_prompt, user_message) do
    chat(user_message, system_prompt)
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
  def stream_chat(message, system_prompt \\ @default_system_prompt) when is_binary(message) do
    messages = [%{role: "user", content: message}]

    case Anthropix.chat(client(),
      model: "claude-3-haiku-20240307",
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
end
