defmodule PhxplateWeb.Dashboard.Account.ActivitiesLive do
  use PhxplateWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:page, 1)
      |> assign(:per_page, 20)
      |> assign(:has_more, length(assigns.activities) >= 20)

    {:ok, socket}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    page = socket.assigns.page + 1
    per_page = socket.assigns.per_page
    user = socket.assigns.user

    # Get next page of activities
    new_activities = Phxplate.Tracking.get_user_activities(user.id, per_page)

    # Check if we have more activities to load
    has_more = length(new_activities) >= per_page

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:has_more, has_more)
     |> update(:activities, &(&1 ++ new_activities))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <.header class="text-center">
        Account Activities
        <:subtitle>View your recent account activities</:subtitle>
      </.header>

      <div class="overflow-hidden rounded-lg bg-white shadow">
        <ul role="list" class="divide-y divide-gray-100">
          <%= for activity <- @activities do %>
            <li class="relative flex justify-between gap-x-6 px-4 py-5 hover:bg-gray-50 sm:px-6">
              <div class="flex min-w-0 gap-x-4">
                <div class="min-w-0 flex-auto">
                  <p class="text-sm font-semibold leading-6 text-gray-900">
                    <span class="absolute inset-x-0 -top-px bottom-0"></span>
                    <%= activity.action %>
                  </p>
                  <p class="mt-1 flex text-xs leading-5 text-gray-500">
                    <%= for {field, value} <- activity.changes do %>
                      <span class="mr-2">
                        <%= field %>: <%= value %>
                      </span>
                    <% end %>
                  </p>
                </div>
              </div>
              <div class="flex shrink-0 items-center gap-x-4">
                <div class="hidden sm:flex sm:flex-col sm:items-end">
                  <p class="text-sm leading-6 text-gray-900">
                    <%= Calendar.strftime(activity.inserted_at, "%B %d, %Y") %>
                  </p>
                  <p class="mt-1 text-xs leading-5 text-gray-500">
                    <%= Calendar.strftime(activity.inserted_at, "%H:%M:%S") %>
                  </p>
                </div>
              </div>
            </li>
          <% end %>
        </ul>

        <div class="bg-white px-4 py-5 sm:px-6">
          <div class="flex justify-center">
            <%= if @has_more do %>
              <.button
                phx-click="load_more"
                phx-target={@myself}
                class="text-center text-sm font-semibold leading-6 text-gray-900"
              >
                Load More
              </.button>
            <% end %>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
