defmodule PhxplateWeb.DashboardLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts.User
  alias PhxplateWeb.PageMeta

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "Dashboard",
       description: "Just the dashboard",
       url: "/dashboard"
     )}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Central Dashboard
        <:subtitle>
          Quick access to your different dashboards
        </:subtitle>
      </.header>
      <div class="mt-4 grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
        <%= if User.is_basic?(@current_user) or User.is_admin?(@current_user) or User.is_super_admin?(@current_user) do %>
          <.dashboard_card
            title="Basic Dashboard"
            description="Access basic features and reports"
            link={~p"/dashboard/basic"}
          />
        <% end %>
        <%= if User.is_admin?(@current_user) or User.is_super_admin?(@current_user) do %>
          <.dashboard_card
            title="Admin Dashboard"
            description="Manage users and system settings"
            link={~p"/dashboard/admin"}
          />
        <% end %>
        <%= if User.is_super_admin?(@current_user) do %>
          <.dashboard_card
            title="Super Admin Dashboard"
            description="Access all system features and controls"
            link={~p"/dashboard/super_admin"}
          />
        <% end %>
      </div>
    </div>
    """
  end

  defp dashboard_card(assigns) do
    ~H"""
    <div class="bg-white shadow rounded-lg p-6 hover:shadow-lg transition-shadow duration-300">
      <h2 class="text-xl font-semibold text-gray-900 mb-2">{@title}</h2>
      <p class="text-gray-600 mb-4">{@description}</p>
      <.link navigate={@link} class="text-blue-600 hover:text-blue-800 font-medium">
        Access Dashboard →
      </.link>
    </div>
    """
  end
end
