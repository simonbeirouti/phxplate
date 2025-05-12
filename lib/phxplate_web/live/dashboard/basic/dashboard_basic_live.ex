defmodule PhxplateWeb.Dashboard.Basic.BasicLive do
  use PhxplateWeb, :live_view
  use SaladUI

  alias PhxplateWeb.PageMeta
  alias Phxplate.Bookmarks

  def mount(_params, _session, socket) do
    bookmark_count = Bookmarks.count_user_bookmarks(socket.assigns.current_user.id)

    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "Basic Dashboard",
       description: "Your personalized dashboard"
     )
     |> assign(:bookmark_count, bookmark_count)}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    {:noreply, socket}
  end

  def render(assigns) do
    ~H"""
    <main>
      <.header>
        <h2 class="text-2xl font-semibold text-gray-900">Basic Dashboard</h2>
        <:subtitle>View your user stats</:subtitle>
      </.header>
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-4">
        <.link navigate={~p"/dashboard/basic/bookmarks"} class="block">
          <div class="bg-white shadow rounded-lg p-4">
            <div class="flex items-center">
              <div class="p-2 bg-green-50 rounded-full">
                <Lucideicons.bookmark fill="black" class="h-6 w-6" />
              </div>
              <div class="ml-4">
                <h3 class="text-lg font-semibold text-gray-900">My Bookmarks</h3>
                <p class="text-2xl font-bold text-green-600">
                  {@bookmark_count}
                </p>
              </div>
            </div>
          </div>
        </.link>
      </div>
    </main>
    """
  end
end
