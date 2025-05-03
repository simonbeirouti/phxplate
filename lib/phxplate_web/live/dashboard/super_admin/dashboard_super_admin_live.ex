defmodule PhxplateWeb.Dashboard.SuperAdmin.SuperAdminLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Accounts, Companies}
  alias PhxplateWeb.PageMeta

  def mount(_params, _session, socket) do
    stats = %{
      total_users: Accounts.count_users(),
      total_companies: Companies.count_companies(),
      total_employees: Companies.count_employees()
    }

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:page_title, "Super Admin Dashboard")
     |> PageMeta.assign_metadata(
       title: "Super Admin Dashboard",
       description: "Super Admin Dashboard"
     )}
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <h1>Super Admin Dashboard</h1>
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
      </div>
    </div>
    """
  end
end
