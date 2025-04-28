defmodule PhxplateWeb.DashboardSuperAdminLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts
  alias Phxplate.Companies

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    companies = Companies.list_companies()
    employees = Companies.list_employees()
    users = Accounts.list_users()

    socket = assign(socket,
      page_title: "Super Admin Dashboard",
      companies: companies,
      employees: employees,
      users: users
    )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Super Admin Dashboard</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <!-- Stats -->
          <div class="mt-8">
            <div class="grid grid-cols-1 gap-5 sm:grid-cols-4">
              <!-- Company Stats -->
              <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Total Companies</dt>
                <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900"><%= length(@companies) %></dd>
              </div>

              <!-- Employee Stats -->
              <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Total Employees</dt>
                <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900"><%= length(@employees) %></dd>
              </div>

              <!-- User Stats -->
              <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Total Users</dt>
                <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900"><%= length(@users) %></dd>
              </div>

              <!-- Admin Stats -->
              <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Admins</dt>
                <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900">
                  <%= Enum.count(@users, &(&1.role == :admin)) %>
                </dd>
              </div>
            </div>
          </div>

          <!-- System Configuration -->
          <div class="mt-8">
            <h2 class="text-lg font-medium leading-6 text-gray-900">System Configuration</h2>
            <div class="mt-4 grid grid-cols-1 gap-5 sm:grid-cols-2">
              <div class="overflow-hidden rounded-lg bg-white shadow">
                <div class="p-5">
                  <h3 class="text-lg font-medium leading-6 text-gray-900">Application Settings</h3>
                  <div class="mt-4">
                    <.link
                      navigate={~p"/super_admin/config"}
                      class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                      Configure
                    </.link>
                  </div>
                </div>
              </div>

              <div class="overflow-hidden rounded-lg bg-white shadow">
                <div class="p-5">
                  <h3 class="text-lg font-medium leading-6 text-gray-900">Audit Logs</h3>
                  <div class="mt-4">
                    <.link
                      navigate={~p"/super_admin/audit"}
                      class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                    >
                      View Logs
                    </.link>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- User Management -->
          <div class="mt-8">
            <h2 class="text-lg font-medium leading-6 text-gray-900">User Management</h2>
            <div class="mt-4 overflow-hidden rounded-lg bg-white shadow">
              <ul role="list" class="divide-y divide-gray-200">
                <%= for user <- @users do %>
                  <li class="px-4 py-4 sm:px-6">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center">
                        <div class="ml-3">
                          <p class="text-sm font-medium text-gray-900"><%= user.email %></p>
                          <p class="text-sm text-gray-500">Role: <%= user.role %></p>
                        </div>
                      </div>
                      <div class="ml-4 flex-shrink-0">
                        <.link
                          navigate={~p"/super_admin/users/#{user}"}
                          class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
                        >
                          Manage
                        </.link>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>

          <!-- Company Management -->
          <div class="mt-8">
            <h2 class="text-lg font-medium leading-6 text-gray-900">Company Management</h2>
            <div class="mt-4 overflow-hidden rounded-lg bg-white shadow">
              <ul role="list" class="divide-y divide-gray-200">
                <%= for company <- @companies do %>
                  <li class="px-4 py-4 sm:px-6">
                    <div class="flex items-center justify-between">
                      <div class="flex items-center">
                        <div class="ml-3">
                          <p class="text-sm font-medium text-gray-900"><%= company.name %></p>
                          <p class="text-sm text-gray-500"><%= company.description %></p>
                        </div>
                      </div>
                      <div class="ml-4 flex-shrink-0">
                        <.link
                          navigate={~p"/super_admin/companies/#{company}"}
                          class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
                        >
                          Manage
                        </.link>
                      </div>
                    </div>
                  </li>
                <% end %>
              </ul>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
