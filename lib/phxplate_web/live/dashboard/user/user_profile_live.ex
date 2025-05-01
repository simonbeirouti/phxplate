defmodule PhxplateWeb.Dashboard.User.UserProfileLive do
  use PhxplateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "User Profile")}
  end

  def render(assigns) do
    ~H"""
    <.header class="text-center">
      User Profile
      <:subtitle>Manage your user profile</:subtitle>
    </.header>
    """
  end
end
