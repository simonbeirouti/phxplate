defmodule PhxplateWeb.Components.ActivityTimelineComponent do
  @moduledoc """
  A live component that displays an activity timeline with pagination support.

  This component shows a chronological list of activities with details about each
  action, including timestamps, changes made, and the actor who performed the action.
  It supports loading more activities through pagination.
  """
  use PhxplateWeb, :live_component
  alias PhxplateWeb.ComponentHelpers

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:page, assigns[:page] || 1)
      |> assign(:per_page, assigns[:per_page] || 20)
      |> assign(:has_more, length(assigns.activities) >= (assigns[:per_page] || 20))

    {:ok, socket}
  end

  @impl true
  def handle_event("load_more", _, socket) do
    page = socket.assigns.page + 1
    per_page = socket.assigns.per_page

    # Get next page of activities based on the type
    new_activities = case socket.assigns do
      %{user_id: user_id} -> Phxplate.Tracking.get_user_activities(user_id, per_page)
      %{company_id: company_id} -> Phxplate.Tracking.get_company_activities(company_id, per_page)
      _ -> []
    end

    # Check if we have more activities to load
    has_more = length(new_activities) >= per_page

    {:noreply,
     socket
     |> assign(:page, page)
     |> assign(:has_more, has_more)
     |> update(:activities, &(&1 ++ new_activities))}
  end

  @doc """
  Renders the activity timeline with pagination support.

  Displays a list of activities with their details and a "Load More" button
  if there are more activities to load.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <%!-- <div class="mb-8 grid grid-cols-2">
        <%= if @show_timestamps && @timestamps do %>
          <%= if @timestamps.confirmed_at do %>
            <div class="col-span-2">
              <h4 class="text-sm font-medium text-gray-500">Email Confirmed</h4>
              <p class="mt-1">
                {Calendar.strftime(@timestamps.confirmed_at, "%B %d, %Y at %I:%M %p")}
              </p>
            </div>
          <% end %>
          <div>
            <h4 class="text-sm font-medium text-gray-500">Created</h4>
            <p class="mt-1">
              {Calendar.strftime(@timestamps.inserted_at, "%B %d, %Y at %I:%M %p")}
            </p>
          </div>
          <div>
            <h4 class="text-sm font-medium text-gray-500">Last Updated</h4>
            <p class="mt-1">
              {Calendar.strftime(@timestamps.updated_at, "%B %d, %Y at %I:%M %p")}
            </p>
          </div>
        <% end %>
      </div> --%>

      <div>
        <div class="mt-4 space-y-4">
          <%= for activity <- @activities do %>
            <div class="border-l-2 border-gray-200 pl-4 pb-4">
              <div class="flex items-start justify-between">
                <div>
                  <p class="font-medium">
                    {ComponentHelpers.humanize_action(activity.action)}
                  </p>
                  <%= if map_size(activity.changes) > 0 do %>
                    <div class="mt-2 text-sm text-gray-600">
                      <p class="font-medium">Changes:</p>
                      <ul class="list-disc list-inside">
                        <%= for {key, value} <- activity.changes do %>
                          <li>{ComponentHelpers.humanize_key(key)}: {inspect(value)}</li>
                        <% end %>
                      </ul>
                    </div>
                  <% end %>
                </div>
                <p class="text-sm text-gray-500">
                  {Calendar.strftime(activity.inserted_at, "%B %d, %Y at %I:%M %p")}
                </p>
              </div>
              <%= if activity.actor do %>
                <p class="text-sm text-gray-500 mt-1">
                  by {activity.actor.email}
                </p>
              <% end %>
            </div>
          <% end %>
        </div>

        <%= if @has_more do %>
          <div class="mt-6">
            <div class="flex justify-center">
              <.button
                phx-click="load_more"
                phx-target={@myself}
                class="text-center text-sm font-semibold leading-6 text-gray-900"
              >
                Load More
              </.button>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
