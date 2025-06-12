defmodule PhxplateWeb.AdminChannel do
  use PhxplateWeb, :channel
  alias Phxplate.Chat
  alias Phxplate.Accounts

  @impl true
  def join("admin:chat", _payload, socket) do
    if authorized?(socket) do
      # Get all active chat sessions for admins
      active_sessions = Chat.list_active_sessions()
      formatted_sessions = format_sessions(active_sessions)

      {:ok, %{sessions: formatted_sessions}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  @impl true
  def handle_in("new_admin_message", %{"session_id" => session_id, "content" => content}, socket) do
    if authorized?(socket) do
      session_id = String.to_integer(session_id)
      user_id = socket.assigns.current_user.id

      attrs = %{
        content: content,
        sender_type: "admin",
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
    else
      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  @impl true
  def handle_in("close_session", %{"session_id" => session_id}, socket) do
    if authorized?(socket) do
      session_id = String.to_integer(session_id)
      session = Chat.get_session(session_id)

      case Chat.close_session(session) do
        {:ok, session} ->
          # Generate and send transcript via email in a separate process
          spawn(fn -> send_transcript(session_id) end)
          {:reply, {:ok, %{session: format_session(session)}}, socket}
        {:error, changeset} ->
          {:reply, {:error, %{errors: format_errors(changeset)}}, socket}
      end
    else
      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  @impl true
  def handle_info({:new_session, session}, socket) do
    if authorized?(socket) do
      push(socket, "new_session", %{session: format_session(session)})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    if authorized?(socket) do
      push(socket, "new_message", %{message: format_message(message)})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_info({:session_closed, session}, socket) do
    if authorized?(socket) do
      push(socket, "session_closed", %{session: format_session(session)})
    end

    {:noreply, socket}
  end

  # Helper functions

  defp format_sessions(sessions) do
    Enum.map(sessions, &format_session/1)
  end

  defp format_session(session) do
    # Get the latest message for this session
    latest_message = Chat.get_latest_message(session.id)

    # Get user info if available
    user_info = if session.user_id do
      user = Accounts.get_user!(session.user_id)
      %{email: user.email, name: user.email, logged_in: true}
    else
      %{email: session.anonymous_email, name: session.anonymous_name, logged_in: false}
    end

    %{
      id: session.id,
      status: session.status,
      started_at: session.started_at,
      user: user_info,
      latest_message: latest_message && format_message(latest_message) || nil
    }
  end

  defp format_message(message) do
    %{
      id: message.id,
      content: message.content,
      sender_type: message.sender_type,
      chat_session_id: message.chat_session_id,
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

  defp authorized?(socket) do
    case socket.assigns[:current_user] do
      %{role: role} when role in [:admin, :super_admin] -> true
      _ -> false
    end
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
