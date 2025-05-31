defmodule PhxplateWeb.UserSocket do
  use Phoenix.Socket

  # A Socket handler
  #
  # It's a good idea to pass the token on connect as below. Checking if
  # it exists allows authentication, but you can handle any claims you need.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # For authenticated users
    case Phoenix.Token.verify(PhxplateWeb.Endpoint, "user socket", token, max_age: 86400) do
      {:ok, user_id} ->
        {:ok, assign(socket, :current_user_id, user_id)}
      {:error, _reason} ->
        # For anonymous users, we still allow connection but without user_id
        {:ok, socket}
    end
  end

  # For anonymous users without a token
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     Elixir.PhxplateWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  @impl true
  def id(socket) do
    if user_id = socket.assigns[:current_user_id] do
      "user_socket:#{user_id}"
    else
      nil
    end
  end

  # Define the channels that can be joined
  channel "chat:session:*", PhxplateWeb.ChatChannel
  channel "admin:chat", PhxplateWeb.AdminChannel
end
