defmodule PhxplateWeb.Dashboard.User.UserAccountLive do
  use PhxplateWeb, :live_view
  alias PhxplateWeb.Dashboard.Account.{ProfileLive, SettingsLive, BillingLive, ActivitiesLive}
  alias Phxplate.Repo
  require Logger

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user |> Repo.preload([:profile, :subscription])
    activities = Phxplate.Tracking.get_user_activities(user.id, 20)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:activities, activities)
      |> assign(:page_title, "User Profile")
      |> assign(:show_status_dialog, false)
      |> assign(:status_message, nil)
      |> assign(:status_type, nil)

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket =
      socket
      |> maybe_show_status_dialog(params["status"])

    {:noreply, socket}
  end

  defp maybe_show_status_dialog(socket, status) do
    {message, type} = case status do
      "success" -> {"Your subscription has been updated successfully.", :success}
      "error" -> {"There was an error processing your subscription. Please try again.", :error}
      "canceled" -> {"Your subscription change was canceled.", :info}
      _ -> {nil, nil}
    end

    if message do
      socket
      |> assign(:show_status_dialog, true)
      |> assign(:status_message, message)
      |> assign(:status_type, type)
    else
      socket
    end
  end

  @impl true
  def handle_event("close_status_dialog", _, socket) do
    {:noreply, assign(socket, :show_status_dialog, false)}
  end

  @impl true
  def handle_info({:flash_msg, type, message}, socket) do
    Logger.debug("Received flash message - Type: #{type}, Message: #{message}")
    {:noreply, put_flash(socket, type, message)}
  end

  @impl true
  def handle_info({:profile_updated, updated_profile}, socket) do
    Logger.debug("Received profile update - Profile ID: #{updated_profile.id}")
    # Update the user's profile in the socket assigns
    user = %{socket.assigns.user | profile: updated_profile}
    {:noreply, assign(socket, :user, user)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        User Profile
        <:subtitle>Manage your user profile, billing, settings and account activity.</:subtitle>
      </.header>

      <.dialog :if={@show_status_dialog} id="status-dialog" show={true}>
        <div class="text-center">
          <div class={"mx-auto flex items-center justify-center h-16 w-16 rounded-full mb-4 #{
            case @status_type do
              :success -> "bg-green-100"
              :error -> "bg-red-100"
              _ -> "bg-blue-100"
            end
          }"}>
            <%= case @status_type do %>
              <% :success -> %>
                <Lucideicons.check class="h-8 w-8 text-green-600" />
              <% :error -> %>
                <Lucideicons.x class="h-8 w-8 text-red-600" />
              <% _ -> %>
                <Lucideicons.info class="h-8 w-8 text-blue-600" />
            <% end %>
          </div>
          <.header>
            <%= case @status_type do %>
              <% :success -> %>
                Subscription Updated
              <% :error -> %>
                Subscription Error
              <% _ -> %>
                Subscription Status
            <% end %>
            <:subtitle><%= @status_message %></:subtitle>
          </.header>

          <.dialog_footer class="mt-4">
            <.button
              phx-click={JS.push("close_status_dialog")}
              class="w-full"
            >
              Close
            </.button>
          </.dialog_footer>
        </div>
      </.dialog>

      <div class="mt-4">
        <.tabs :let={builder} default="profile" id="user_tabs" class="w-full">
          <.tabs_list>
            <.tabs_trigger value="profile" builder={builder}>
              Profile
            </.tabs_trigger>

            <.tabs_trigger value="subscription" builder={builder}>
              Subscription
            </.tabs_trigger>

            <.tabs_trigger value="settings" builder={builder}>
              Settings
            </.tabs_trigger>

            <.tabs_trigger value="activities" builder={builder}>
              Activities
            </.tabs_trigger>
          </.tabs_list>

          <.tabs_content value="profile">
            <.live_component module={ProfileLive} id="user_profile_form" user={@user} />
          </.tabs_content>

          <.tabs_content value="subscription">
            <.live_component module={BillingLive} id="user_billing" user={@user} />
          </.tabs_content>

          <.tabs_content value="settings">
            <.live_component module={SettingsLive} id="user_settings" user={@user} />
          </.tabs_content>

          <.tabs_content value="activities">
            <.live_component
              module={ActivitiesLive}
              id="user_activities"
              user={@user}
              activities={@activities}
            />
          </.tabs_content>
        </.tabs>
      </div>
    </div>
    """
  end
end
