defmodule PhxplateWeb.Dashboard.Admin.AdminLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Companies, Subscriptions}
  alias Phxplate.PubSub.DataSync
  import PhxplateWeb.Components.CompaniesGrid
  import PhxplateWeb.CoreComponents
  import PhxplateWeb.Dashboard.Admin.CompanyHelpers

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      # Subscribe to both user-specific and global company updates
      DataSync.subscribe("companies", current_user.id)
      DataSync.subscribe("companies", "all")
    end

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

  @impl true
  def handle_info({:created, %{type: :company, company: company}}, socket) do
    # Only add the company if it belongs to the current user and isn't already in the list
    if company.owner_id == socket.assigns.current_user.id and not Enum.any?(socket.assigns.companies, &(&1.id == company.id)) do
      {:noreply, update(socket, :companies, fn companies -> [company | companies] end)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:updated, %{type: :company, company: company}}, socket) do
    # Only update if it's one of our companies
    if company.owner_id == socket.assigns.current_user.id do
      {:noreply,
       update(socket, :companies, fn companies ->
         Enum.map(companies, fn c -> if c.id == company.id, do: company, else: c end)
       end)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :company, id: company_id}}, socket) do
    {:noreply,
     update(socket, :companies, fn companies ->
       Enum.reject(companies, &(&1.id == company_id))
     end)}
  end

  def handle_event("open_create_company_dialog", params, socket) do
    handle_open_create_company_dialog(socket)
  end

  def handle_event("create_company", params, socket) do
    handle_create_company(socket, params)
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Admin Dashboard
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
