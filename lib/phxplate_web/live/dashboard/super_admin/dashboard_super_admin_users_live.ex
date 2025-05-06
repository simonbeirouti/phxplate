defmodule PhxplateWeb.Dashboard.SuperAdmin.UsersLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Accounts, Repo}
  alias PhxplateWeb.PageMeta

  def mount(_params, _session, socket) do
    # Load available plans for the subscription management
    plans = Phxplate.Subscriptions.list_all_plans()

    socket =
      socket
      |> assign(:selected_user, nil)
      |> assign(:plans, plans)
      |> assign(:subscription_statuses, [:active, :canceled, :past_due, :incomplete, :trialing])
      |> assign(:paid_tiers, [:none, :small, :medium, :large])
      |> assign(:delete_confirmation, false)

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

  def handle_event("update_role", %{"role" => role, "user_id" => user_id}, socket) do
    role = String.to_existing_atom(role)
    user = Accounts.get_user!(user_id)

    case Accounts.update_user(user, %{role: role}) do
      {:ok, updated_user} ->
        # Reload the user with associations
        updated_user = Repo.preload(updated_user, [:profile, :subscription])

        socket =
          socket
          |> assign(:selected_user, updated_user)
          |> load_users(socket.assigns.page)
          |> put_flash(:info, "User role updated successfully")

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update user role")}
    end
  end

  def handle_event(
        "update_subscription_status",
        %{"user_id" => user_id, "status" => status},
        socket
      ) do
    with %{role: :super_admin} <- socket.assigns.current_user,
         user = Accounts.get_user!(user_id) |> Repo.preload(:subscription),
         status = String.to_existing_atom(status) do
      result =
        if user.subscription do
          Phxplate.Subscriptions.admin_update_subscription_status(user.subscription, status)
        else
          # Create a new subscription with basic tier if none exists
          Phxplate.Subscriptions.admin_create_subscription(user_id, :small, status)
        end

      case result do
        {:ok, _subscription} ->
          # Reload the user to get the updated subscription
          updated_user = Accounts.get_user!(user_id) |> Repo.preload([:profile, :subscription])

          socket =
            socket
            |> assign(:selected_user, updated_user)
            |> load_users(socket.assigns.page)
            |> put_flash(:info, "Subscription status updated successfully")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update subscription status")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update subscription status")}
    end
  end

  def handle_event("update_subscription_tier", %{"user_id" => user_id, "tier" => tier}, socket) do
    with %{role: :super_admin} <- socket.assigns.current_user,
         user = Accounts.get_user!(user_id) |> Repo.preload(:subscription),
         tier = String.to_existing_atom(tier) do
      result =
        if user.subscription do
          Phxplate.Subscriptions.admin_update_subscription_tier(user.subscription, tier)
        else
          # Create a new subscription
          Phxplate.Subscriptions.admin_create_subscription(
            user_id,
            tier,
            if(tier == :none, do: :canceled, else: :active)
          )
        end

      case result do
        {:ok, _subscription} ->
          # Reload the user to get the updated subscription
          updated_user = Accounts.get_user!(user_id) |> Repo.preload([:profile, :subscription])

          socket =
            socket
            |> assign(:selected_user, updated_user)
            |> load_users(socket.assigns.page)
            |> put_flash(:info, "Subscription tier updated successfully")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to update subscription tier")}
      end
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to update subscription tier")}
    end
  end

  def handle_event("delete_user", _params, socket) do
    {:noreply, assign(socket, :delete_confirmation, true)}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_confirmation, false)}
  end

  def handle_event("confirm_delete_user", %{"user_id" => user_id}, socket) do
    with %{role: :super_admin} <- socket.assigns.current_user,
         user = Accounts.get_user!(user_id),
         {:ok, _deleted} <- Accounts.delete_user(user) do
      socket =
        socket
        |> assign(:selected_user, nil)
        |> assign(:delete_confirmation, false)
        |> load_users(socket.assigns.page)
        |> put_flash(:info, "User deleted successfully")

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Failed to delete user")}
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

      <div class="grid grid-cols-1 md:grid-cols-2 gap-8 mt-4 h-[calc(100vh-200px)]">
        <div class="h-[calc(100vh-200px)] col-span-1">
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
                  <Lucideicons.arrow_right class="w-5 h-5 mr-2" />
                </div>
              </div>
            <% end %>
          </div>

          <%= if @total_pages > 1 do %>
            <div class="mt-6">
              <.pagination>
                <.pagination_content class="w-full flex justify-center items-center">
                  <%= if @page > 1 do %>
                    <.pagination_item>
                      <.pagination_link phx-click="paginate" phx-value-page={@page - 1}>
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
          <% end %>
        </div>

        <div class="col-span-1">
          <h2 class="text-xl font-semibold mb-4">User Details</h2>
          <%= if @selected_user do %>
            <.tabs :let={builder} default="profile" id="user-details">
              <.tabs_list class="grid w-full grid-cols-3">
                <.tabs_trigger builder={builder} value="profile">Profile</.tabs_trigger>
                <.tabs_trigger builder={builder} value="account">Account</.tabs_trigger>
                <.tabs_trigger builder={builder} value="timeline">Timeline</.tabs_trigger>
              </.tabs_list>

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
                              <a
                                href={url}
                                target="_blank"
                                rel="noopener noreferrer"
                                class="inline-flex mr-2"
                              >
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

              <.tabs_content value="account">
                <div class="space-y-4 p-4">
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Email</h4>
                      <p class="mt-1">{@selected_user.email}</p>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Account Status</h4>
                      <p class="mt-1">
                        {if @selected_user.confirmed_at, do: "Confirmed", else: "Pending Confirmation"}
                      </p>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Role</h4>
                      <form phx-change="update_role" class="mt-2">
                        <.select
                          :let={select}
                          id="role-select"
                          name="role"
                          value={@selected_user.role}
                        >
                          <.select_trigger builder={select} class="capitalize w-[180px]" />
                          <.select_content builder={select}>
                            <.select_item builder={select} value="basic" label="Basic">
                              Basic
                            </.select_item>
                            <.select_item builder={select} value="admin" label="Admin">
                              Admin
                            </.select_item>
                            <.select_item builder={select} value="super_admin" label="Super Admin">
                              Super Admin
                            </.select_item>
                          </.select_content>
                        </.select>
                        <input type="hidden" name="user_id" value={@selected_user.id} />
                      </form>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Subscription Status</h4>
                      <form phx-change="update_subscription_status" class="mt-2">
                        <.select
                          :let={select}
                          id="status-select"
                          name="status"
                          value={
                            if @selected_user.subscription,
                              do: @selected_user.subscription.subscription_status
                          }
                          placeholder={if @selected_user.subscription, do: nil, else: "Select status"}
                        >
                          <.select_trigger builder={select} class="capitalize w-[180px]" />
                          <.select_content builder={select}>
                            <%= for status <- @subscription_statuses do %>
                              <.select_item
                                class="capitalize"
                                builder={select}
                                value={status}
                                label={status}
                              >
                                <span>{status}</span>
                              </.select_item>
                            <% end %>
                          </.select_content>
                        </.select>
                        <input type="hidden" name="user_id" value={@selected_user.id} />
                      </form>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Current Plan</h4>
                      <form phx-change="update_subscription_tier" class="mt-2">
                        <.select
                          :let={select}
                          id="tier-select"
                          name="tier"
                          value={
                            if @selected_user.subscription, do: @selected_user.subscription.paid_tier
                          }
                          placeholder={if @selected_user.subscription, do: nil, else: "Select plan"}
                        >
                          <.select_trigger builder={select} class="capitalize w-[180px]" />
                          <.select_content builder={select}>
                            <%= for tier <- @paid_tiers do %>
                              <.select_item
                                class="capitalize"
                                builder={select}
                                value={tier}
                                label={tier}
                              >
                                <span>{tier}</span>
                              </.select_item>
                            <% end %>
                          </.select_content>
                        </.select>
                        <input type="hidden" name="user_id" value={@selected_user.id} />
                      </form>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Subscription End Date</h4>
                      <p class="mt-1">
                        <%= if @selected_user.subscription && @selected_user.subscription.subscription_period_end do %>
                          {Calendar.strftime(
                            @selected_user.subscription.subscription_period_end,
                            "%B %d, %Y"
                          )}
                        <% else %>
                          N/A
                        <% end %>
                      </p>
                    </div>
                  </div>
                  <div class="grid grid-cols-2 gap-4">
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Customer ID</h4>
                      <p class="mt-1">
                        <%= if @selected_user.subscription do %>
                          {@selected_user.subscription.stripe_customer_id}
                        <% else %>
                          No customer ID
                        <% end %>
                      </p>
                    </div>
                    <div>
                      <h4 class="text-sm font-medium text-gray-500">Subscription ID</h4>
                      <p class="mt-1">
                        <%= if @selected_user.subscription do %>
                          {@selected_user.subscription.stripe_subscription_id}
                        <% else %>
                          No subscription ID
                        <% end %>
                      </p>
                    </div>
                  </div>

                  <div class="mt-8 border-t pt-6">
                    <%= if @delete_confirmation do %>
                      <div class="flex space-x-4">
                        <button
                          phx-click="confirm_delete_user"
                          phx-value-user_id={@selected_user.id}
                          class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                        >
                          Confirm Delete
                        </button>
                        <button
                          phx-click="cancel_delete"
                          class="inline-flex items-center px-3 py-2 border border-gray-300 text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
                        >
                          Cancel
                        </button>
                      </div>
                    <% else %>
                      <button
                        phx-click="delete_user"
                        class="inline-flex items-center px-3 py-2 border border-transparent text-sm leading-4 font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
                      >
                        Delete User Account
                      </button>
                    <% end %>
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
