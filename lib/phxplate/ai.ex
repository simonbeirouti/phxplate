defmodule Phxplate.AI do
  @moduledoc """
  AI module for interacting with Anthropic Claude using the Anthropix library.
  """

  @doc """
  Initialize an Anthropix client using the configured API key.
  """
  def client do
    Anthropix.init()
  end

  @doc """
  Send a simple text message to Claude and get a response.

  ## Examples

      iex> Phxplate.AI.chat("Hello, how are you?")
      {:ok, "Hello! I'm doing well, thank you for asking..."}

      iex> Phxplate.AI.chat("What is the capital of France?")
      {:ok, "The capital of France is Paris."}
  """
  def chat(message) when is_binary(message) do
    messages = [%{role: "user", content: message}]

    case Anthropix.chat(client(), model: "claude-3-haiku-20240307", messages: messages) do
      {:ok, %{"content" => [%{"text" => text}]}} -> {:ok, text}
      {:ok, response} -> {:ok, extract_text_from_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a conversation (list of messages) to Claude.

  ## Examples

      messages = [
        %{role: "user", content: "What is 2+2?"},
        %{role: "assistant", content: "2+2 equals 4."},
        %{role: "user", content: "What about 3+3?"}
      ]

      Phxplate.AI.chat_conversation(messages)
  """
  def chat_conversation(messages) when is_list(messages) do
    case Anthropix.chat(client(), model: "claude-3-haiku-20240307", messages: messages) do
      {:ok, %{"content" => [%{"text" => text}]}} -> {:ok, text}
      {:ok, response} -> {:ok, extract_text_from_response(response)}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a message to Claude with a system prompt.

  ## Examples

      Phxplate.AI.chat_with_system(
        "You are a helpful coding assistant.",
        "How do I create a Phoenix LiveView component?"
      )
  """
  def chat_with_system(system_prompt, user_message) do
    messages = [%{role: "user", content: user_message}]

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
  Stream a conversation with Claude for real-time responses.

  ## Examples

      {:ok, stream} = Phxplate.AI.stream_chat("Tell me a story")

      stream
      |> Stream.each(&IO.puts/1)
      |> Stream.run()
  """
  def stream_chat(message) when is_binary(message) do
    messages = [%{role: "user", content: message}]

    Anthropix.chat(client(),
      model: "claude-3-haiku-20240307",
      messages: messages,
      stream: true
    )
  end

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
