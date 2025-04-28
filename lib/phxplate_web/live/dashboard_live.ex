defmodule PhxplateWeb.DashboardLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Accounts
  alias Phxplate.Companies

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    companies = Companies.list_companies()
    employees = Companies.list_employees()
    team_members = Accounts.list_users()

    socket = assign(socket,
      page_title: "Dashboard",
      companies: companies,
      employees: employees,
      team_members: team_members
    )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Dashboard</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <!-- Stats -->
          <div class="mt-8">
            <div class="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-3">
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

              <!-- Team Stats -->
              <div class="overflow-hidden rounded-lg bg-white px-4 py-5 shadow sm:p-6">
                <dt class="truncate text-sm font-medium text-gray-500">Team Members</dt>
                <dd class="mt-1 text-3xl font-semibold tracking-tight text-gray-900"><%= length(@team_members) %></dd>
              </div>
            </div>
          </div>

          <!-- Recent Activity -->
          <div class="mt-8">
            <h2 class="text-lg font-medium leading-6 text-gray-900">Recent Activity</h2>
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
                        <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                          Active
                        </span>
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
