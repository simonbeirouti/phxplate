defmodule PhxplateWeb.UserSessionHandlerLive do
  use PhxplateWeb, :live_component
  alias Phoenix.PubSub

  @impl true
  def update(%{current_user: current_user} = assigns, socket) do
    if connected?(socket) and current_user do
      # Only subscribe if we have a current_user with an id
      if current_user.id do
        PubSub.subscribe(Phxplate.PubSub, "users:#{current_user.id}")
      end
    end

    {:ok, assign(socket, current_user: current_user)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={"user-session-handler-#{@myself.cid}"} phx-hook="ForceLogout" style="display: none;"></div>
    """
  end

  @impl true
  def handle_info({:force_logout, _payload}, socket) do
    {:noreply, push_event(socket, "js_force_logout", %{reason: "user_deleted"})}
  end
end
