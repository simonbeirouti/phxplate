defmodule PhxplateWeb.Dashboard.Basic.BookmarksLive do
  @moduledoc """
  LiveView for displaying and managing user bookmarks.

  This view shows a list of companies that the user has bookmarked
  for quick access. It subscribes to real-time updates for bookmarks
  via PubSub, allowing for immediate UI updates when bookmarks are
  created or deleted.
  """
  use PhxplateWeb, :live_view

  alias Phxplate.{Bookmarks, PubSub.DataSync}
  alias PhxplateWeb.PageMeta

  @doc """
  Initializes the LiveView with the user's bookmarks.

  Sets up PubSub subscription for bookmark updates and assigns
  the initial list of bookmarks to the socket.
  """
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      DataSync.subscribe("bookmarks", socket.assigns.current_user.id)
    end

    # Fetch bookmarks with company and employees preloaded
    bookmarks =
      Bookmarks.list_user_bookmarks(socket.assigns.current_user.id)
      |> Enum.map(fn bookmark ->
        %{bookmark | company: Phxplate.Repo.preload(bookmark.company, :employees)}
      end)

    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "My Bookmarks",
       description: "Companies you've bookmarked for quick access",
       url: "/dashboard/basic/bookmarks"
     )
     |> assign(bookmarks: bookmarks)}
  end

  @impl true
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:created, %{type: :bookmark, bookmark: bookmark}}, socket) do
    # Only add the bookmark if it doesn't already exist in the list
    case Enum.find(socket.assigns.bookmarks, &(&1.id == bookmark.id)) do
      nil ->
        # Reload the bookmark with company association and employees
        bookmark =
          Bookmarks.get_bookmark(bookmark.user_id, bookmark.company_id)
          |> Phxplate.Repo.preload(company: :employees)

        # Update the list, ensuring no duplicates
        {:noreply,
         update(socket, :bookmarks, fn bookmarks ->
           Enum.uniq_by([bookmark | bookmarks], & &1.id)
         end)}

      _existing ->
        {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :bookmark, id: bookmark_id}}, socket) do
    {:noreply,
     update(socket, :bookmarks, fn bookmarks ->
       Enum.reject(bookmarks, &(&1.id == bookmark_id))
     end)}
  end

  # Helper function to check if a user is the owner of a company
  defp is_owner?(company, user_id) do
    company.owner_id == user_id
  end

  # Helper function to check if a user is an employee of a company
  defp is_employee?(company, user_email) do
    Enum.any?(company.employees, &(&1.email == user_email))
  end

  @doc """
  Renders the bookmarks view showing a grid of bookmarked companies.

  For each bookmark, displays a card with the company logo, name, and description.
  If no bookmarks exist, shows a message with a link to browse companies.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1">
      <.header>
        My Bookmarks
        <:subtitle>Companies you've bookmarked for quick access</:subtitle>
      </.header>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-4">
        <%= for bookmark <- @bookmarks do %>
          <.link
            navigate={
              cond do
                is_owner?(bookmark.company, @current_user.id) -> ~p"/dashboard/admin/companies/#{bookmark.company.id}"
                is_employee?(bookmark.company, @current_user.email) -> ~p"/dashboard/companies/#{bookmark.company.id}"
                true -> ~p"/companies/#{bookmark.company.id}"
              end
            }
            class="block"
          >
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
