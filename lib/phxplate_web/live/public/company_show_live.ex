defmodule PhxplateWeb.Public.CompanyShowLive do
  use PhxplateWeb, :live_view
  use SaladUI

  alias Phxplate.Companies
  alias Phxplate.Bookmarks

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    company = Companies.get_company!(id)

    bookmarked =
      if socket.assigns.current_user do
        Bookmarks.bookmarked?(socket.assigns.current_user.id, company.id)
      else
        false
      end

    {:ok, assign(socket, company: company, bookmarked: bookmarked)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto">
      <div class="my-6">
        <.link navigate={~p"/companies"}>
          <.button variant="outline">
            ← Back to Companies
          </.button>
        </.link>
      </div>
      <div class="bg-white shadow overflow-hidden rounded-lg">
        <div class="relative h-64 sm:h-96 bg-gray-200">
          <%= if @company.logo do %>
            <img src={@company.logo} alt={@company.name} class="h-full w-full object-cover" />
          <% else %>
            <div class="absolute inset-0 flex items-center justify-center">
              <div class="text-6xl font-bold text-gray-400">
                {String.first(@company.name)}
              </div>
            </div>
          <% end %>
        </div>

        <div class="px-4 py-5 sm:px-6">
          <div class="flex items-center justify-between">
            <h3 class="text-3xl font-bold text-gray-900">{@company.name}</h3>
            <%= if @current_user do %>
              <button
                phx-click={if @bookmarked, do: "unbookmark", else: "bookmark"}
                class="inline-flex items-center px-4 py-2 border rounded-md shadow-sm text-sm font-medium">
                <%= if @bookmarked do %>
                  <Lucideicons.bookmark fill="currentColor" class="h-5 w-5" />
                <% else %>
                  <Lucideicons.bookmark fill="none" class="h-5 w-5" />
                <% end %>
              </button>
            <% end %>
          </div>
          <%= if @company.description do %>
            <p class="mt-4 text-gray-600">{@company.description}</p>
          <% end %>
        </div>

        <div class="border-t border-gray-200 px-4 py-5 sm:px-6">
          <dl class="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
            <%= if @company.website do %>
              <div class="sm:col-span-1">
                <dt class="text-sm font-medium text-gray-500">Website</dt>
                <dd class="mt-1">
                  <a href={@company.website} target="_blank" class="text-blue-600 hover:text-blue-500">
                    {@company.website}
                  </a>
                </dd>
              </div>
            <% end %>

            <%= if @company.email do %>
              <div class="sm:col-span-1">
                <dt class="text-sm font-medium text-gray-500">Email</dt>
                <dd class="mt-1">
                  <a href={"mailto:#{@company.email}"} class="text-blue-600 hover:text-blue-500">
                    {@company.email}
                  </a>
                </dd>
              </div>
            <% end %>

            <%= if @company.phone do %>
              <div class="sm:col-span-1">
                <dt class="text-sm font-medium text-gray-500">Phone</dt>
                <dd class="mt-1">
                  <a href={"tel:#{@company.phone}"} class="text-blue-600 hover:text-blue-500">
                    {@company.phone}
                  </a>
                </dd>
              </div>
            <% end %>

            <%= if @company.address do %>
              <div class="sm:col-span-1">
                <dt class="text-sm font-medium text-gray-500">Address</dt>
                <dd class="mt-1 text-gray-900">{@company.address}</dd>
              </div>
            <% end %>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("bookmark", _params, socket) do
    case Bookmarks.create_bookmark(%{
           user_id: socket.assigns.current_user.id,
           company_id: socket.assigns.company.id
         }) do
      {:ok, _bookmark} ->
        {:noreply,
         socket
         |> assign(:bookmarked, true)
         |> put_flash(:info, "Company bookmarked successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, error_to_string(changeset))}
    end
  end

  @impl true
  def handle_event("unbookmark", _params, socket) do
    bookmark = Bookmarks.get_bookmark(socket.assigns.current_user.id, socket.assigns.company.id)

    case Bookmarks.delete_bookmark(bookmark) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:bookmarked, false)
         |> put_flash(:info, "Bookmark removed successfully.")}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not remove bookmark.")}
    end
  end

  defp error_to_string(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map(fn {_key, value} -> value end)
    |> List.flatten()
    |> Enum.join(", ")
  end
end
