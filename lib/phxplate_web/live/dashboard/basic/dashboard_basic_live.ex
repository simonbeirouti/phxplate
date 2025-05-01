defmodule PhxplateWeb.Dashboard.Basic.BasicLive do
  use PhxplateWeb, :live_view
  alias PhxplateWeb.PageMeta

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "Basic Dashboard",
       description: "Just the basic dashboard"
     )}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    data =
      case socket.assigns.live_action do
        :index ->
          %{
            message: "Welcome to Basic Dashboard",
            features: ["Basic Reports", "Personal Settings", "Standard Features"]
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
      </div>
    </main>
    """
  end
end
