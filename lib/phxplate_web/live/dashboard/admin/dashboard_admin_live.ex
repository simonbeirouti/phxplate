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
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <h2 class="text-2xl font-semibold text-gray-900">Admin Dashboard</h2>
        <:subtitle>View your company dashboard here</:subtitle>
      </.header>
      <div class="mt-4">
        <.link navigate="#">
          <div class="relative overflow-hidden rounded-lg p-4 shadow hover:bg-gray-50 transition-colors">
            <div class="absolute rounded-md p-3">
              <Lucideicons.building class="h-8 w-8 text-black" />
            </div>
            <div class="ml-16">
              <p class="truncate text-sm font-medium text-gray-500">Total Companies</p>
              <p class="mt-1 text-3xl font-semibold text-gray-900">{@stats.total_companies}</p>
            </div>
          </div>
        </.link>
      </div>
    </div>
    """
  end
end
