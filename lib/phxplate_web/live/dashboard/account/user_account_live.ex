defmodule PhxplateWeb.Dashboard.User.UserAccountLive do
  use PhxplateWeb, :live_view
  alias PhxplateWeb.Dashboard.Account.{ProfileLive, SettingsLive, BillingLive, ActivitiesLive}
  alias Phxplate.Repo

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user |> Repo.preload([:profile, :subscription])
    activities = Phxplate.Tracking.get_user_activities(user.id, 20)

    socket =
      socket
      |> assign(:user, user)
      |> assign(:activities, activities)
      |> assign(:page_title, "User Profile")

    {:ok, socket}
  end

  @impl true
  def handle_info({:flash_msg, type, message}, socket) do
    {:noreply, put_flash(socket, type, message)}
  end

  @impl true
  def handle_info({:profile_updated, updated_profile}, socket) do
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
