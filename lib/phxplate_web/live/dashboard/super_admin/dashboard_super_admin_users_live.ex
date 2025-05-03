defmodule PhxplateWeb.Dashboard.SuperAdmin.UsersLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Accounts, Repo}
  alias PhxplateWeb.PageMeta
  alias PhxplateWeb.Components.UI.Tabs
  import Tabs

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    users =
      Accounts.list_users()
      |> Repo.preload([:profile, :subscription])
      |> Enum.reject(fn user -> user.id == current_user.id end)

    {:ok,
     socket
     |> assign(:users, users)
     |> assign(:selected_user, nil)
     |> PageMeta.assign_metadata(
       title: "Super Admin Users",
       description: "Manage users across the application"
     )}
  end

  def handle_event("select_user", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(user_id) |> Repo.preload([:profile, :subscription])
    {:noreply, assign(socket, selected_user: user)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <h1>User Management</h1>
        <:subtitle>Manage users across the application</:subtitle>
      </.header>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mt-4 h-[calc(100vh-200px)]">

        <div class="h-[calc(100vh-200px)] col-span-3 md:col-span-1">
          <h2 class="text-xl font-semibold mb-4">User List</h2>
          <div class="divide-y">
            <%= for user <- @users do %>
              <div
                class="py-4 cursor-pointer hover:bg-gray-50 transition-colors"
                phx-click="select_user"
                phx-value-id={user.id}
              >
                <div class="flex items-center justify-between">
                  <div>
                    <p class="font-medium">{user.email}</p>
                    <p class="text-sm text-gray-500">ID: {user.id}</p>
                  </div>
                  <span class="text-gray-400">&rarr;</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="col-span-3 md:col-span-2">
          <h2 class="text-xl font-semibold mb-4">User Details</h2>
          <%= if @selected_user do %>
            <.tabs :let={builder} default="account" id="user-details">
              <.tabs_list class="grid w-full grid-cols-4">
                <.tabs_trigger builder={builder} value="account">Account</.tabs_trigger>
                <.tabs_trigger builder={builder} value="profile">Profile</.tabs_trigger>
                <.tabs_trigger builder={builder} value="billing">Billing</.tabs_trigger>
                <.tabs_trigger builder={builder} value="timeline">Timeline</.tabs_trigger>
              </.tabs_list>

              <.tabs_content value="account">
                <div class="space-y-4 p-4">
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Email</h4>
                    <p class="mt-1">{@selected_user.email}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Role</h4>
                    <p class="mt-1">{@selected_user.role}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Account Status</h4>
                    <p class="mt-1">
                      {if @selected_user.confirmed_at, do: "Confirmed", else: "Pending Confirmation"}
                    </p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">ID</h4>
                    <p class="mt-1">{@selected_user.id}</p>
                  </div>
                </div>
              </.tabs_content>

              <.tabs_content value="profile">
                <div class="space-y-4 p-4">
                  <%= if @selected_user.profile do %>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">First Name</h4>
                      <p class="mt-1">{@selected_user.profile.first_name || "Not provided"}</p>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Last Name</h4>
                      <p class="mt-1">{@selected_user.profile.last_name || "Not provided"}</p>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Phone</h4>
                      <p class="mt-1">{@selected_user.profile.phone || "Not provided"}</p>
                    </div>
                  <% else %>
                    <p class="text-gray-500">No profile information available</p>
                  <% end %>
                </div>
              </.tabs_content>

              <.tabs_content value="billing">
                <div class="space-y-4 p-4">
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Subscription Status</h4>
                    <p class="mt-1">
                      <%= if @selected_user.subscription do %>
                        <%= @selected_user.subscription.subscription_status || "No active subscription" %>
                      <% else %>
                        No subscription
                      <% end %>
                    </p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Current Plan</h4>
                    <p class="mt-1">
                      <%= if @selected_user.subscription do %>
                        <%= @selected_user.subscription.paid_tier || "No plan" %>
                      <% else %>
                        No plan
                      <% end %>
                    </p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Subscription End Date</h4>
                    <p class="mt-1">
                      <%= if @selected_user.subscription && @selected_user.subscription.subscription_period_end do %>
                        <%= Calendar.strftime(@selected_user.subscription.subscription_period_end, "%B %d, %Y") %>
                      <% else %>
                        N/A
                      <% end %>
                    </p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Customer ID</h4>
                    <p class="mt-1">
                      <%= if @selected_user.subscription do %>
                        <%= @selected_user.subscription.stripe_customer_id %>
                      <% else %>
                        No customer ID
                      <% end %>
                    </p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Subscription ID</h4>
                    <p class="mt-1">
                      <%= if @selected_user.subscription do %>
                        <%= @selected_user.subscription.stripe_subscription_id %>
                      <% else %>
                        No subscription ID
                      <% end %>
                    </p>
                  </div>
                </div>
              </.tabs_content>

              <.tabs_content value="timeline">
                <div class="space-y-4 p-4">
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Created</h4>
                    <p class="mt-1">
                      {Calendar.strftime(@selected_user.inserted_at, "%B %d, %Y at %I:%M %p")}
                    </p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Last Updated</h4>
                    <p class="mt-1">
                      {Calendar.strftime(@selected_user.updated_at, "%B %d, %Y at %I:%M %p")}
                    </p>
                  </div>
                  <%= if @selected_user.confirmed_at do %>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Email Confirmed</h4>
                      <p class="mt-1">
                        {Calendar.strftime(@selected_user.confirmed_at, "%B %d, %Y at %I:%M %p")}
                      </p>
                    </div>
                  <% end %>
                </div>
              </.tabs_content>
            </.tabs>
          <% else %>
            <p class="text-gray-500">Select a user to view details</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
