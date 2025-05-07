defmodule PhxplateWeb.Dashboard.Basic.BookmarksLive do
  use PhxplateWeb, :live_view
  use SaladUI

  alias Phxplate.Bookmarks

  @impl true
  def mount(_params, _session, socket) do
    bookmarks = Bookmarks.list_user_bookmarks(socket.assigns.current_user.id)

    {:ok,
     assign(socket,
       page_title: "My Bookmarks",
       page_description: "Companies you've bookmarked for quick access",
       bookmarks: bookmarks
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1">
      <.header>
        <h1>My Bookmarks</h1>
        <:subtitle>Companies you've bookmarked for quick access</:subtitle>
      </.header>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-4">
        <%= for bookmark <- @bookmarks do %>
          <.link navigate={~p"/companies/#{bookmark.company.id}"} class="block">
            <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow duration-200">
              <div class="h-48 bg-gray-200 flex items-center justify-center">
                <%= if bookmark.company.logo do %>
                  <img
                    src={bookmark.company.logo}
                    alt={bookmark.company.name}
                    class="h-full w-full object-cover"
                  />
                <% else %>
                  <div class="text-4xl font-bold text-gray-400">
                    {String.first(bookmark.company.name)}
                  </div>
                <% end %>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold text-gray-900">{bookmark.company.name}</h3>
                <%= if bookmark.company.description do %>
                  <p class="mt-2 text-gray-600 line-clamp-2">{bookmark.company.description}</p>
                <% end %>
              </div>
            </div>
          </.link>
        <% end %>

        <%= if Enum.empty?(@bookmarks) do %>
          <div class="col-span-full text-center py-12">
            <div class="text-gray-400">
              <Lucideicons.bookmark class="mx-auto h-12 w-12" />
              <h3 class="mt-2 text-sm font-semibold text-gray-900">No bookmarks</h3>
              <p class="mt-1 text-sm text-gray-500">Get started by bookmarking some companies.</p>
              <div class="mt-6">
                <.link navigate={~p"/companies"}>
                  <.button>Browse Companies</.button>
                </.link>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
