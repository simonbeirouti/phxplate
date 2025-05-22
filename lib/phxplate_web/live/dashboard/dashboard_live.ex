defmodule PhxplateWeb.DashboardLive do
  @moduledoc """
  LiveView for the central dashboard.

  This view provides a centralized entry point to various dashboards based on the user's
  role (basic, admin, or super admin). It displays dashboard cards that link to the
  appropriate role-specific dashboards that the current user has access to.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts.User
  alias PhxplateWeb.PageMeta

  @doc """
  Initializes the LiveView with page metadata.

  Sets up the page title, description, and URL for the central dashboard.
  """
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "Dashboard",
       description: "Just the dashboard",
       url: "/dashboard"
     )}
  end

  @doc """
  Handles URL parameters and updates the layout data with current path.
  """
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    {:noreply, socket}
  end

  @doc """
  Renders the central dashboard view with role-specific dashboard cards.

  Displays dashboard cards for basic, admin, and super admin dashboards
  based on the user's role, with each card linking to the appropriate dashboard.
  """
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
    <.link navigate={@link}>
      <div class="bg-white shadow rounded-lg p-6 hover:shadow-lg transition-shadow duration-300">
        <h2 class="text-xl font-semibold text-gray-900 mb-2">{@title}</h2>
        <p class="text-gray-600 mb-4">{@description}</p>
        <p class="text-blue-600 hover:text-blue-800 font-medium">
          Access Dashboard →
        </p>
      </div>
    </.link>
    """
  end
end
