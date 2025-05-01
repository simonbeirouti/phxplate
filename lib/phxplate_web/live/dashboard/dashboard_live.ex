defmodule PhxplateWeb.DashboardLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts.User

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Dashboard",
       page_description: "Just the dashboard",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com"
     )}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8">
      <h1 class="text-3xl font-bold mb-6">Dashboard</h1>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
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
