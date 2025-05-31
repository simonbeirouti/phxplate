defmodule Phxplate.Chat do
  @moduledoc """
  The Chat context.
  Provides functions for managing chat sessions and messages.
  """

  alias Phxplate.Chat.ChatSession
  alias Phxplate.Chat.ChatMessage
  alias Phxplate.Accounts.User
  alias Phxplate.Repo
  alias Phoenix.PubSub

  # Session-related functions

  @doc """
  Creates a new chat session.
  """
  def create_session(attrs) do
    ChatSession.create_session(attrs)
  end

  @doc """
  Gets a chat session by ID.
  """
  def get_session(id), do: ChatSession.get_session(id)

  @doc """
  Gets a chat session with preloaded messages.
  """
  def get_session_with_messages(id), do: ChatSession.get_session_with_messages(id)

  @doc """
  Lists all active chat sessions.
  """
  def list_active_sessions, do: ChatSession.list_active_sessions()
  
  @doc """
  Lists chat sessions with pagination support.
  
  ## Options
  
    * `:page` - The page number (default: 1)
    * `:per_page` - The number of items per page (default: 10)
  """
  def list_sessions(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)
    
    ChatSession.list_sessions(page, per_page)
  end
  
  @doc """
  Returns the total count of chat sessions.
  """
  def count_sessions do
    ChatSession.count_sessions()
  end

  @doc """
  Closes a chat session.
  """
  def close_session(session) do
    with {:ok, session} <- ChatSession.close_session(session) do
      # Broadcast session closure to all relevant channels
      PubSub.broadcast(Phxplate.PubSub, "chat:session:#{session.id}", {:session_closed, session})
      PubSub.broadcast(Phxplate.PubSub, "admin:chat", {:session_closed, session})
      
      {:ok, session}
    end
  end

  @doc """
  Gets all chat sessions for a user.
  """
  def get_user_sessions(user_id), do: ChatSession.get_sessions_for_user(user_id)
  
  @doc """
  Gets all chat sessions for an anonymous user by email.
  """
  def get_anonymous_sessions(email), do: ChatSession.get_sessions_for_anonymous(email)

  # Message-related functions

  @doc """
  Creates a new chat message and broadcasts it to the relevant channels.
  """
  def create_message(attrs) do
    with {:ok, message} <- ChatMessage.create_message(attrs) do
      # Broadcast to session-specific channel
      PubSub.broadcast(Phxplate.PubSub, "chat:session:#{message.chat_session_id}", {:new_message, message})
      
      # Broadcast to admin channel for monitoring
      PubSub.broadcast(Phxplate.PubSub, "admin:chat", {:new_message, message})
      
      {:ok, message}
    end
  end

  @doc """
  Gets a message by ID.
  """
  def get_message(id), do: ChatMessage.get_message(id)

  @doc """
  Gets all messages for a session.
  """
  def get_session_messages(session_id), do: ChatMessage.get_messages_for_session(session_id)

  @doc """
  Gets the latest message for a session.
  """
  def get_latest_message(session_id), do: ChatMessage.get_latest_message(session_id)

  @doc """
  Sends a notification about a new chat session to admins.
  """
  def notify_new_session(session) do
    PubSub.broadcast(Phxplate.PubSub, "admin:chat", {:new_session, session})
  end

  @doc """
  Generates a chat transcript for a session.
  """
  def generate_transcript(session_id) do
    session = get_session_with_messages(session_id)
    
    # Format the transcript
    messages = Enum.map(session.messages, fn message ->
      timestamp = message.inserted_at |> DateTime.to_naive() |> NaiveDateTime.to_string()
      sender = if message.sender_type == "admin", do: "Support Agent", else: get_sender_name(session, message)
      "[#{timestamp}] #{sender}: #{message.content}"
    end)
    
    # Join the messages with newlines
    Enum.join(["Chat Transcript - #{session.inserted_at}"] ++ messages, "\n")
  end

  # Helper function to get the sender name
  defp get_sender_name(session, message) do
    cond do
      message.user_id -> 
        user = Repo.get(User, message.user_id)
        user && user.email || "User"
      session.anonymous_name -> 
        session.anonymous_name
      true -> 
        "User"
    end
  end
end
