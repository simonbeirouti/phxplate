defmodule PhxplateWeb.Dashboard.Admin.AdminLive do
  use PhxplateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Admin Dashboard", data: nil)}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    data =
      case socket.assigns.live_action do
        :index ->
          %{
            message: "Welcome to Admin Dashboard",
            features: ["User Management", "System Settings", "Advanced Reports"],
            users: [
              %{email: "user1@example.com", role: "basic"},
              %{email: "admin@example.com", role: "admin"}
            ]
          }

        _ ->
          nil
      end

    {:noreply, assign(socket, data: data)}
  end

  def render(assigns) do
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
end
