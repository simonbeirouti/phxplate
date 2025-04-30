defmodule PhxplateWeb.DashboardLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts.User

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Dashboard", data: nil)}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    data = case socket.assigns.live_action do
      :basic -> %{
        message: "Welcome to Basic Dashboard",
        features: ["Basic Reports", "Personal Settings", "Standard Features"]
      }
      :admin -> %{
        message: "Welcome to Admin Dashboard",
        features: ["User Management", "System Settings", "Advanced Reports"],
        users: [
          %{email: "user1@example.com", role: "basic"},
          %{email: "admin@example.com", role: "admin"}
        ]
      }
      :super_admin -> %{
        message: "Welcome to Super Admin Dashboard",
        features: ["System Configuration", "Full Access Control", "Audit Logs"],
        system_stats: %{
          total_users: "1,234",
          active_users: "789",
          system_status: "Healthy"
        }
      }
      _ -> nil
    end

    {:noreply, assign(socket, data: data)}
  end

  def render(%{live_action: :basic} = assigns), do: basic(assigns)
  def render(%{live_action: :admin} = assigns), do: admin(assigns)
  def render(%{live_action: :super_admin} = assigns), do: super_admin(assigns)
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

  def basic(assigns) do
    ~H"""
    <main>
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-2xl font-semibold text-gray-900">{@data.message}</h2>
        <div class="mt-4">
          <h3 class="text-lg font-medium text-gray-900">Available Features:</h3>
          <ul class="mt-2 list-disc list-inside">
            <%= for feature <- @data.features do %>
              <li class="text-gray-600">{feature}</li>
            <% end %>
          </ul>
        </div>
      </div>
    </main>
    """
  end

  def admin(assigns) do
    ~H"""
    <main>
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-2xl font-semibold text-gray-900">{@data.message}</h2>
        <div class="mt-4">
          <h3 class="text-lg font-medium text-gray-900">Available Features:</h3>
          <ul class="mt-2 list-disc list-inside">
            <%= for feature <- @data.features do %>
              <li class="text-gray-600">{feature}</li>
            <% end %>
          </ul>
        </div>
        <div class="mt-6">
          <h3 class="text-lg font-medium text-gray-900">User List:</h3>
          <div class="mt-2 overflow-x-auto">
            <table class="min-w-full divide-y divide-gray-200">
              <thead class="bg-gray-50">
                <tr>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Email
                  </th>
                  <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                    Role
                  </th>
                </tr>
              </thead>
              <tbody class="bg-white divide-y divide-gray-200">
                <%= for user <- @data.users do %>
                  <tr>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                      {user.email}
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">{user.role}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </main>
    """
  end

  def super_admin(assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">
            Super Admin Dashboard 2
          </h1>
        </div>
      </header>
      <main>
        <div>
          <div>
            <div class="bg-white shadow rounded-lg p-6">
              <h2 class="text-2xl font-semibold text-gray-900">{@data.message}</h2>
              <div class="mt-4">
                <h3 class="text-lg font-medium text-gray-900">Available Features:</h3>
                <ul class="mt-2 list-disc list-inside">
                  <%= for feature <- @data.features do %>
                    <li class="text-gray-600">{feature}</li>
                  <% end %>
                </ul>
              </div>
              <div class="mt-6">
                <h3 class="text-lg font-medium text-gray-900">System Statistics:</h3>
                <div class="mt-4 grid grid-cols-1 gap-5 sm:grid-cols-3">
                  <div class="bg-white overflow-hidden shadow rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                      <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                      <dd class="mt-1 text-3xl font-semibold text-gray-900">
                        {@data.system_stats.total_users}
                      </dd>
                    </div>
                  </div>
                  <div class="bg-white overflow-hidden shadow rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                      <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
                      <dd class="mt-1 text-3xl font-semibold text-gray-900">
                        {@data.system_stats.active_users}
                      </dd>
                    </div>
                  </div>
                  <div class="bg-white overflow-hidden shadow rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                      <dt class="text-sm font-medium text-gray-500 truncate">System Status</dt>
                      <dd class="mt-1 text-3xl font-semibold text-green-600">
                        {@data.system_stats.system_status}
                      </dd>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
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
