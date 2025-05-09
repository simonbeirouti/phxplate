defmodule PhxplateWeb.Dashboard.Admin.AdminLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Companies, Subscriptions}
  import PhxplateWeb.Components.CompaniesGrid

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    companies = Companies.list_companies_by_owner(current_user.id)
    # For super admin, we pass nil subscription which will give unlimited access
    subscription = if current_user.role == :super_admin do
      %{plan: %{features: %{"projects" => "Unlimited"}}}
    else
      Subscriptions.get_user_subscription(current_user.id)
    end

    {:ok,
     assign(socket,
       page_title: "Admin Dashboard",
       companies: companies,
       subscription: subscription
     )}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:noreply, socket}
  end

  def handle_event("create_company", _params, socket) do
    {:noreply, put_flash(socket, :info, "Company creation feature coming soon!")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <h2 class="text-2xl font-semibold text-gray-900">Admin Dashboard</h2>
        <:subtitle>
          View your dashboard here and companies that you've created
        </:subtitle>
      </.header>

      <div class="mt-4 grid grid-cols-1 sm:grid-cols-2 gap-4 mb-6">
        <div class="bg-white shadow rounded-lg p-4">
          <div class="flex items-center">
            <div class="p-2 bg-blue-50 rounded-full">
              <Lucideicons.building_2 class="w-6 h-6 text-blue-600" />
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-semibold text-gray-900">Total Companies</h3>
              <p class="text-2xl font-bold text-blue-600"><%= length(@companies) %></p>
            </div>
          </div>
        </div>
        <div class="bg-white shadow rounded-lg p-4">
          <div class="flex items-center">
            <div class="p-2 bg-green-50 rounded-full">
              <Lucideicons.users class="w-6 h-6 text-green-600" />
            </div>
            <div class="ml-4">
              <h3 class="text-lg font-semibold text-gray-900">Total Employees</h3>
              <p class="text-2xl font-bold text-green-600">
                <%= Enum.reduce(@companies, 0, fn company, acc ->
                  acc + length(Companies.get_company_employees(company))
                end) %>
              </p>
            </div>
          </div>
        </div>
      </div>

      <.companies_grid
        companies={@companies}
        subscription={@subscription}
        on_create="create_company"
      />
    </div>
    """
  end
end
