defmodule PhxplateWeb.Dashboard.SuperAdmin.UsersLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Accounts, Repo}
  alias PhxplateWeb.PageMeta

  def mount(_params, _session, socket) do
    # Load available plans for the subscription management
    plans = Phxplate.Subscriptions.list_all_plans()

    socket = socket
      |> assign(:selected_user, nil)
      |> assign(:plans, plans)
      |> assign(:subscription_statuses, [:active, :canceled, :past_due, :incomplete, :trialing])
      |> assign(:paid_tiers, [:small, :medium, :large])

    {:ok, load_users(socket, 1)}
  end

  defp load_users(socket, page) do
    per_page = 10

    # Get total count for pagination
    total_users = Accounts.count_users()
    total_pages = max(1, ceil(total_users / per_page))

    # Get paginated users
    users =
      Accounts.list_users(page: page, per_page: per_page)
      |> Repo.preload([:profile, :subscription])

    socket
    |> assign(:users, users)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:per_page, per_page)
    |> PageMeta.assign_metadata(
      title: "Super Admin Users",
      description: "Manage users across the application"
    )
  end

  def handle_event("select_user", %{"id" => user_id}, socket) do
    user = Accounts.get_user!(user_id) |> Repo.preload([:profile, :subscription])
    {:noreply, assign(socket, selected_user: user)}
  end

  def handle_event("update_subscription_status", %{"user_id" => user_id, "status" => status}, socket) do
    with %{role: :super_admin} <- socket.assigns.current_user,
         user = Accounts.get_user!(user_id) |> Repo.preload(:subscription),
         {:ok, _subscription} <- Phxplate.Subscriptions.admin_update_subscription_status(user.subscription, status) do
      # Reload the user to get the updated subscription
      updated_user = Accounts.get_user!(user_id) |> Repo.preload([:profile, :subscription])
      {:noreply, assign(socket, selected_user: updated_user)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update subscription status")}
    end
  end

  def handle_event("update_subscription_tier", %{"user_id" => user_id, "tier" => tier}, socket) do
    with %{role: :super_admin} <- socket.assigns.current_user,
         user = Accounts.get_user!(user_id) |> Repo.preload(:subscription),
         {:ok, _subscription} <- Phxplate.Subscriptions.admin_update_subscription_tier(user.subscription, tier) do
      # Reload the user to get the updated subscription
      updated_user = Accounts.get_user!(user_id) |> Repo.preload([:profile, :subscription])
      {:noreply, assign(socket, selected_user: updated_user)}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update subscription tier")}
    end
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    {:noreply, load_users(socket, page)}
  end

  def handle_params(params, _uri, socket) do
    page =
      case params["page"] do
        nil -> 1
        page_param -> String.to_integer(page_param)
      end

    {:noreply, load_users(socket, page)}
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

          <div class="mt-6">
            <.pagination>
              <.pagination_content class="w-full flex justify-center items-center">
                <%= if @page > 1 do %>
                  <.pagination_item>
                    <.pagination_link href={~p"/dashboard/super_admin/users?page=#{@page - 1}"}>
                      <Lucideicons.arrow_left class="w-3.5 h-3.5" />
                    </.pagination_link>
                  </.pagination_item>
                <% end %>

                <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                  <.pagination_item>
                    <.pagination_link
                      phx-click="paginate"
                      phx-value-page={page_num}
                      is-active={page_num == @page}
                    >
                      {page_num}
                    </.pagination_link>
                  </.pagination_item>
                <% end %>

                <%= if @page < @total_pages do %>
                  <.pagination_item>
                    <.pagination_link phx-click="paginate" phx-value-page={@page + 1}>
                      <Lucideicons.arrow_right class="w-3.5 h-3.5" />
                    </.pagination_link>
                  </.pagination_item>
                <% end %>
              </.pagination_content>
            </.pagination>
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
                    <div class="grid grid-cols-2 gap-4">
                      <div class="col-span-1 flex items-center justify-center">
                        <img
                          class="w-48 h-48 rounded-full"
                          src={@selected_user.profile.avatar_url || ""}
                          alt="Avatar"
                        />
                      </div>
                      <div class="col-span-1 flex flex-col gap-4">
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
                      </div>
                      <div class="col-span-2">
                        <h4 class="text-sm font-medium text-gray-500">Bio</h4>
                        <p class="mt-1">{@selected_user.profile.bio || "Not provided"}</p>
                      </div>
                      <div class="col-span-1">
                        <h4 class="text-sm font-medium text-gray-500">Location</h4>
                        <p class="mt-1">{@selected_user.profile.location || "Not provided"}</p>
                      </div>
                      <div class="col-span-1">
                        <h4 class="text-sm font-medium text-gray-500">Website</h4>
                        <p class="mt-1">{@selected_user.profile.website || "Not provided"}</p>
                      </div>
                      <div class="col-span-2">
                        <h4 class="text-sm font-medium text-gray-500">Social Links</h4>
                        <div class="mt-1 w-full flex flex-wrap">
                          <%= if @selected_user.profile.social_links && map_size(@selected_user.profile.social_links) > 0 do %>
                            <%= for {platform, url} <- @selected_user.profile.social_links do %>
                              <a href={url} target="_blank" rel="noopener noreferrer" class="inline-flex mr-2">
                                <.button class="flex flex-row items-center gap-2">
                                  <span class="capitalize">{platform}</span>
                                  <Lucideicons.external_link class="w-3.5 h-3.5 ml-2" />
                                </.button>
                              </a>
                            <% end %>
                          <% else %>
                            <p>Not provided</p>
                          <% end %>
                        </div>
                      </div>
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
