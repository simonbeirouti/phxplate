defmodule PhxplateWeb.DashboardHTML do
  use PhxplateWeb, :html
  alias Phxplate.Accounts.User

  embed_templates "dashboard_html/*"

  def render("index.html", assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Dashboard</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="px-4 py-8 sm:px-0">
            <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
              <%= if User.is_basic?(@current_user) or User.is_admin?(@current_user) or User.is_super_admin?(@current_user) do %>
                <.link navigate={~p"/dashboard/basic"} class="block p-6 bg-white rounded-lg shadow hover:bg-gray-50">
                  <h2 class="text-xl font-semibold text-gray-900">Basic Dashboard</h2>
                  <p class="mt-2 text-gray-600">Access basic features and reports</p>
                </.link>
              <% end %>

              <%= if User.is_admin?(@current_user) or User.is_super_admin?(@current_user) do %>
                <.link navigate={~p"/dashboard/admin"} class="block p-6 bg-white rounded-lg shadow hover:bg-gray-50">
                  <h2 class="text-xl font-semibold text-gray-900">Admin Dashboard</h2>
                  <p class="mt-2 text-gray-600">Manage users and system settings</p>
                </.link>
              <% end %>

              <%= if User.is_super_admin?(@current_user) do %>
                <.link navigate={~p"/dashboard/super_admin"} class="block p-6 bg-white rounded-lg shadow hover:bg-gray-50">
                  <h2 class="text-xl font-semibold text-gray-900">Super Admin Dashboard</h2>
                  <p class="mt-2 text-gray-600">Access all system features and controls</p>
                </.link>
              <% end %>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  def render("basic.html", assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Basic Dashboard</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="px-4 py-8 sm:px-0">
            <div class="bg-white shadow rounded-lg p-6">
              <h2 class="text-2xl font-semibold text-gray-900"><%= @data.message %></h2>
              <div class="mt-4">
                <h3 class="text-lg font-medium text-gray-900">Available Features:</h3>
                <ul class="mt-2 list-disc list-inside">
                  <%= for feature <- @data.features do %>
                    <li class="text-gray-600"><%= feature %></li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  def render("admin.html", assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Admin Dashboard</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="px-4 py-8 sm:px-0">
            <div class="bg-white shadow rounded-lg p-6">
              <h2 class="text-2xl font-semibold text-gray-900"><%= @data.message %></h2>
              <div class="mt-4">
                <h3 class="text-lg font-medium text-gray-900">Available Features:</h3>
                <ul class="mt-2 list-disc list-inside">
                  <%= for feature <- @data.features do %>
                    <li class="text-gray-600"><%= feature %></li>
                  <% end %>
                </ul>
              </div>
              <div class="mt-6">
                <h3 class="text-lg font-medium text-gray-900">User List:</h3>
                <div class="mt-2 overflow-x-auto">
                  <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                      <tr>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                        <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Role</th>
                      </tr>
                    </thead>
                    <tbody class="bg-white divide-y divide-gray-200">
                      <%= for user <- @data.users do %>
                        <tr>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900"><%= user.email %></td>
                          <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500"><%= user.role %></td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end

  def render("super_admin.html", assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Super Admin Dashboard</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="px-4 py-8 sm:px-0">
            <div class="bg-white shadow rounded-lg p-6">
              <h2 class="text-2xl font-semibold text-gray-900"><%= @data.message %></h2>
              <div class="mt-4">
                <h3 class="text-lg font-medium text-gray-900">Available Features:</h3>
                <ul class="mt-2 list-disc list-inside">
                  <%= for feature <- @data.features do %>
                    <li class="text-gray-600"><%= feature %></li>
                  <% end %>
                </ul>
              </div>
              <div class="mt-6">
                <h3 class="text-lg font-medium text-gray-900">System Statistics:</h3>
                <div class="mt-4 grid grid-cols-1 gap-5 sm:grid-cols-3">
                  <div class="bg-white overflow-hidden shadow rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                      <dt class="text-sm font-medium text-gray-500 truncate">Total Users</dt>
                      <dd class="mt-1 text-3xl font-semibold text-gray-900"><%= @data.system_stats.total_users %></dd>
                    </div>
                  </div>
                  <div class="bg-white overflow-hidden shadow rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                      <dt class="text-sm font-medium text-gray-500 truncate">Active Users</dt>
                      <dd class="mt-1 text-3xl font-semibold text-gray-900"><%= @data.system_stats.active_users %></dd>
                    </div>
                  </div>
                  <div class="bg-white overflow-hidden shadow rounded-lg">
                    <div class="px-4 py-5 sm:p-6">
                      <dt class="text-sm font-medium text-gray-500 truncate">System Status</dt>
                      <dd class="mt-1 text-3xl font-semibold text-green-600"><%= @data.system_stats.system_status %></dd>
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
end
