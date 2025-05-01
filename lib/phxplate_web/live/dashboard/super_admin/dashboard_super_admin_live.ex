defmodule PhxplateWeb.Dashboard.SuperAdmin.SuperAdminLive do
  use PhxplateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Super admin dashboard",
       page_description: "Just the super admin dashboard",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com"
     )}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    data = case socket.assigns.live_action do
      :index -> %{
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

  def render(assigns) do
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
end
