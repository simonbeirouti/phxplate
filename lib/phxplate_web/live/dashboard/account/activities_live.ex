defmodule PhxplateWeb.Dashboard.Account.ActivitiesLive do
  use PhxplateWeb, :live_component
  alias PhxplateWeb.Components.ActivityTimelineComponent

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:show_timestamps, false)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        module={ActivityTimelineComponent}
        id={"activity-timeline-#{@user.id}"}
        activities={@activities}
        user_id={@user.id}
        show_timestamps={false}
      />
    </div>
    """
  end
end
