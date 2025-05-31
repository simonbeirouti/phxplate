defmodule PhxplateWeb.ChatChannel do
  use PhxplateWeb, :channel
  alias Phxplate.Chat
  alias Phxplate.Accounts
  
  @impl true
  def join("chat:session:" <> session_id, _payload, socket) do
    session_id = String.to_integer(session_id)
    
    case Chat.get_session_with_messages(session_id) do
      nil ->
        {:error, %{reason: "Chat session not found"}}
      session ->
        if session.status == "closed" do
          {:error, %{reason: "Chat session is closed"}}
        else
          socket = assign(socket, :session_id, session_id)
          {:ok, %{messages: format_messages(session.messages)}, socket}
        end
    end
  end

  @impl true
  def handle_in("new_message", %{"content" => content}, socket) do
    session_id = socket.assigns.session_id
    # Get session but don't use it directly (we just need to verify it exists)
    _session = Chat.get_session(session_id)
    
    sender_type = "user"
    user_id = socket.assigns[:current_user_id]
    
    attrs = %{
      content: content,
      sender_type: sender_type,
      chat_session_id: session_id,
      user_id: user_id
    }
    
    case Chat.create_message(attrs) do
      {:ok, message} ->
        # The broadcast is handled in the Chat context
        {:reply, {:ok, %{message: format_message(message)}}, socket}
      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_in("close_session", _params, socket) do
    session_id = socket.assigns.session_id
    session = Chat.get_session(session_id)
    
    case Chat.close_session(session) do
      {:ok, _session} ->
        # Generate and send transcript via email in a separate process
        spawn(fn -> send_transcript(session_id) end)
        {:reply, :ok, socket}
      {:error, changeset} ->
        {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if message.chat_session_id == socket.assigns.session_id do
      push(socket, "new_message", %{message: format_message(message)})
    end
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_closed, session}, socket) do
    if session.id == socket.assigns.session_id do
      push(socket, "session_closed", %{})
    end
    
    {:noreply, socket}
  end

  # Helper functions
  
  defp format_messages(messages) do
    Enum.map(messages, &format_message/1)
  end

  defp format_message(message) do
    %{
      id: message.id,
      content: message.content,
      sender_type: message.sender_type,
      inserted_at: message.inserted_at
    }
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  defp send_transcript(session_id) do
    session = Chat.get_session_with_messages(session_id)
    transcript = Chat.generate_transcript(session_id)
    
    # Determine the email to send to
    email = cond do
      session.user_id -> 
        user = Accounts.get_user!(session.user_id)
        user.email
      session.anonymous_email -> 
        session.anonymous_email
      true -> nil
    end
    
    if email do
      # Send email with transcript
      # This would use your email service (e.g., Swoosh)
      # PhxplateWeb.Email.send_chat_transcript(email, transcript)
      # For now, we'll just log it
      IO.puts("Sending transcript to #{email}")
      IO.puts(transcript)
    end
  end
end
