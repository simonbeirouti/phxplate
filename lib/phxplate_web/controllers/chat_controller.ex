defmodule PhxplateWeb.ChatController do
  use PhxplateWeb, :controller
  alias Phxplate.Chat

  def create(conn, %{"chat" => chat_params}) do
    # Extract user information if logged in
    attrs = case conn.assigns[:current_user] do
      nil ->
        # For anonymous users, require name and email
        %{
          anonymous_name: chat_params["name"],
          anonymous_email: chat_params["email"],
          started_at: DateTime.utc_now()
        }
      user ->
        # For logged in users, use their account info
        %{
          user_id: user.id,
          started_at: DateTime.utc_now()
        }
    end

    case Chat.create_session(attrs) do
      {:ok, session} ->
        # Notify admins about the new session
        Chat.notify_new_session(session)

        # Return the session ID for the frontend to connect to the channel
        json(conn, %{session_id: session.id})
      {:error, _changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Could not create chat session"})
    end
  end

  def get_session(conn, %{"id" => session_id}) do
    session = Chat.get_session_with_messages(session_id)

    if session do
      # Check if the user is authorized to access this session
      authorized = cond do
        # Logged in user owns the session
        conn.assigns[:current_user] && session.user_id == conn.assigns[:current_user].id ->
          true
        # Anonymous user with matching email in params
        session.anonymous_email && conn.params["email"] == session.anonymous_email ->
          true
        # Admin users can access all sessions (you would need to implement this check)
        # is_admin?(conn.assigns[:current_user]) -> true
        true ->
          false
      end

      if authorized do
        json(conn, %{
          session: %{
            id: session.id,
            status: session.status,
            anonymous_name: session.anonymous_name,
            anonymous_email: session.anonymous_email,
            started_at: session.started_at,
            messages: Enum.map(session.messages, fn msg ->
              %{
                id: msg.id,
                content: msg.content,
                sender_type: msg.sender_type,
                inserted_at: msg.inserted_at
              }
            end)
          }
        })
      else
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Not authorized to access this chat session"})
      end
    else
      conn
      |> put_status(:not_found)
      |> json(%{error: "Chat session not found"})
    end
  end

  def get_anonymous_sessions(conn, %{"email" => email}) do
    sessions = Chat.get_anonymous_sessions(email)

    json(conn, %{
      sessions: Enum.map(sessions, fn session ->
        %{
          id: session.id,
          status: session.status,
          anonymous_name: session.anonymous_name,
          started_at: session.started_at,
          message_count: length(session.messages),
          last_message: if Enum.any?(session.messages) do
            msg = List.last(session.messages)
            %{
              content: String.slice(msg.content, 0, 50) <> (if String.length(msg.content) > 50, do: "...", else: ""),
              sender_type: msg.sender_type,
              inserted_at: msg.inserted_at
            }
          else
            nil
          end
        }
      end)
    })
  end
end
