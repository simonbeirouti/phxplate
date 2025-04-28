defmodule PhxplateWeb.DashboardBasicLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Companies

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    companies = Companies.list_companies()
    employees = Companies.list_employees()

    socket = assign(socket,
      page_title: "Basic Dashboard",
      companies: companies,
      employees: employees
    )

    {:ok, socket}
  end

  def render(assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Basic Dashboard</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <!-- Stats -->
          <div class="mt-8">
            <div class="grid grid-cols-1 gap-5 sm:grid-cols-2">
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
            </div>
          </div>

          <!-- Company List -->
          <div class="mt-8">
            <h2 class="text-lg font-medium leading-6 text-gray-900">Companies</h2>
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
                          navigate={~p"/companies/#{company}"}
                          class="text-sm font-medium text-indigo-600 hover:text-indigo-500"
                        >
                          View
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
