defmodule PhxplateWeb.Dashboard.SuperAdmin.SuperAdminLive do
  @moduledoc """
  LiveView for the super admin dashboard.

  This view provides an overview of application-wide statistics for super admins,
  including total user count, company count, employee count, subscription metrics,
  and revenue data. It subscribes to real-time updates for users, companies,
  employees, and subscriptions via PubSub to ensure statistics stay current.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.{Accounts, Companies, Subscriptions}
  alias PhxplateWeb.PageMeta
  alias Phxplate.PubSub.DataSync

  @doc """
  Initializes the LiveView with application statistics and PubSub subscriptions.

  Collects summary statistics about users, companies, employees, subscriptions,
  and revenue. Sets up PubSub subscriptions for real-time updates to these metrics.
  """
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to all relevant topics for real-time updates
      DataSync.subscribe("companies", "all")
      DataSync.subscribe("employees", "all")
      DataSync.subscribe("users", "all")
      DataSync.subscribe("subscriptions", "all")
      DataSync.subscribe("profiles", "all")
    end

    stats = %{
      total_users: Accounts.count_users(),
      total_companies: Companies.count_companies(),
      total_employees: Companies.count_employees(),
      total_subscriptions: Subscriptions.count_active_subscriptions(),
      total_revenue: Subscriptions.calculate_total_revenue()
    }

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:page_title, "Super Admin Dashboard")
     |> PageMeta.assign_metadata(
       title: "Super Admin Dashboard",
       description: "Super Admin Dashboard",
       url: "/dashboard/super_admin"
     )}
  end

  @impl true
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:noreply, socket}
  end

  # Handle employee creation - only global scope
  @impl true
  def handle_info({:created, %{type: :employee, employee: _employee, global_scope: true}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_employees: Companies.count_employees()}
     end)}
  end

  # Handle employee deletion with full employee data - only global scope
  def handle_info({:deleted, %{type: :employee, employee: _employee, global_scope: true}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_employees: Companies.count_employees()}
     end)}
  end

  # Handle company creation
  def handle_info({:created, %{type: :company, company: _company}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_companies: stats.total_companies + 1}
     end)}
  end

  # Handle company deletion
  def handle_info({:deleted, %{type: :company, id: _company_id}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_companies: stats.total_companies - 1}
     end)}
  end

  # Handle user creation
  def handle_info({:created, %{type: :user, user: _user}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_users: stats.total_users + 1}
     end)}
  end

  # Handle user deletion
  def handle_info({:deleted, %{type: :user, id: _user_id}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_users: stats.total_users - 1}
     end)}
  end

  # Handle subscription changes
  def handle_info({event, %{type: :subscription} = data}, socket) do
    case event do
      :created ->
        {:noreply,
         update(socket, :stats, fn stats ->
           %{stats |
             total_subscriptions: stats.total_subscriptions + 1,
             total_revenue: stats.total_revenue + (data.subscription.amount || 0)
           }
         end)}

      :deleted ->
        {:noreply,
         update(socket, :stats, fn stats ->
           %{stats |
             total_subscriptions: stats.total_subscriptions - 1,
             total_revenue: stats.total_revenue - (data.subscription.amount || 0)
           }
         end)}

      :updated ->
        # For updates, we only need to recalculate revenue if the amount changed
        if data.changes && Map.has_key?(data.changes, :amount) do
          old_amount = data.subscription.amount - data.changes.amount
          {:noreply,
           update(socket, :stats, fn stats ->
             %{stats |
               total_revenue: stats.total_revenue - old_amount + data.subscription.amount
             }
           end)}
        else
          {:noreply, socket}
        end
    end
  end

  # Catch-all for any other events
  def handle_info(_message, socket), do: {:noreply, socket}

  @doc """
  Renders the super admin dashboard with statistics cards.

  Displays a summary of application statistics including users, companies,
  employees, subscriptions, and revenue in card format, with appropriate icons
  and links to detailed views.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Super Admin Dashboard
        <:subtitle>View the stats of the application here</:subtitle>
      </.header>
      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 mt-4">
        <.link navigate={~p"/dashboard/super_admin/users"} class="block">
          <div class="relative overflow-hidden rounded-lg p-4 shadow hover:bg-gray-50 transition-colors">
            <div class="absolute rounded-md p-3">
              <Lucideicons.users class="h-8 w-8 text-black" />
            </div>
            <div class="ml-16">
              <p class="truncate text-sm font-medium text-gray-500">Total Users</p>
              <p class="mt-1 text-3xl font-semibold text-gray-900">{@stats.total_users}</p>
            </div>
          </div>
        </.link>

        <.link navigate={~p"/dashboard/super_admin/companies"} class="block">
          <div class="relative overflow-hidden rounded-lg p-4 shadow hover:bg-gray-50 transition-colors">
            <div class="absolute rounded-md p-3">
              <Lucideicons.building class="h-8 w-8 text-black" />
            </div>
            <div class="ml-16">
              <p class="truncate text-sm font-medium text-gray-500">Total Companies</p>
              <p class="mt-1 text-3xl font-semibold text-gray-900">{@stats.total_companies}</p>
            </div>
          </div>
        </.link>

        <div class="relative overflow-hidden rounded-lg p-4 shadow">
          <div class="absolute rounded-md p-3">
            <Lucideicons.users class="h-8 w-8 text-black" />
          </div>
          <div class="ml-16">
            <p class="truncate text-sm font-medium text-gray-500">Total Employees</p>
            <p class="mt-1 text-3xl font-semibold text-gray-900">{@stats.total_employees}</p>
          </div>
        </div>

        <div class="relative overflow-hidden rounded-lg p-4 shadow">
          <div class="absolute rounded-md p-3">
            <Lucideicons.credit_card class="h-8 w-8 text-black" />
          </div>
          <div class="ml-16">
            <p class="truncate text-sm font-medium text-gray-500">Active Subscriptions</p>
            <p class="mt-1 text-3xl font-semibold text-gray-900">{@stats.total_subscriptions}</p>
          </div>
        </div>

        <div class="relative overflow-hidden rounded-lg p-4 shadow">
          <div class="absolute rounded-md p-3">
            <Lucideicons.dollar_sign class="h-8 w-8 text-black" />
          </div>
          <div class="ml-16">
            <p class="truncate text-sm font-medium text-gray-500">Total Revenue</p>
            <p class="mt-1 text-3xl font-semibold text-gray-900">$ {@stats.total_revenue}</p>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
