defmodule PhxplateWeb.Dashboard.Admin.AdminLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Companies, Subscriptions}
  alias Phxplate.PubSub.DataSync
  alias PhxplateWeb.PageMeta
  import PhxplateWeb.Components.CompaniesGrid
  import PhxplateWeb.CoreComponents
  import PhxplateWeb.Dashboard.Admin.CompanyHelpers

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      # Subscribe to both user-specific and global company updates
      DataSync.subscribe("companies", current_user.id)
      DataSync.subscribe("companies", "all")
      # Subscribe to employee updates for all companies; will filter relevance in handle_info
      DataSync.subscribe("employees", "all")
      # Subscribe to user-specific events for force logout
      DataSync.subscribe("users", current_user.id)
    end

    companies = Companies.list_companies_by_owner(current_user.id)
    employee_count = calculate_employee_count(companies)

    # For super admin, we pass nil subscription which will give unlimited access
    subscription = if current_user.role == :super_admin do
      %{plan: %{features: %{"projects" => "Unlimited"}}}
    else
      Subscriptions.get_user_subscription(current_user.id)
    end

    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "Admin Dashboard",
       description: "View your dashboard and companies that you've created",
       url: "/dashboard/admin"
     )
     |> assign(
       companies: companies,
       employee_count: employee_count,
       subscription: subscription
     )}
  end

  @impl true
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:noreply, socket}
  end

  @impl true
  def handle_info({:created, %{type: :company, company: company}}, socket) do
    # Only add the company if it belongs to the current user and isn't already in the list
    if company.owner_id == socket.assigns.current_user.id and not Enum.any?(socket.assigns.companies, &(&1.id == company.id)) do
      updated_companies = [company | socket.assigns.companies]
      employee_count = calculate_employee_count(updated_companies)
      {:noreply, assign(socket, companies: updated_companies, employee_count: employee_count)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:updated, %{type: :company, company: company}}, socket) do
    # Only update if it's one of our companies
    if company.owner_id == socket.assigns.current_user.id do
      updated_companies =
        Enum.map(socket.assigns.companies, fn c -> if c.id == company.id, do: company, else: c end)
      employee_count = calculate_employee_count(updated_companies)
      {:noreply, assign(socket, companies: updated_companies, employee_count: employee_count)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :company, id: company_id}}, socket) do
    updated_companies = Enum.reject(socket.assigns.companies, &(&1.id == company_id))
    employee_count = calculate_employee_count(updated_companies)
    {:noreply, assign(socket, companies: updated_companies, employee_count: employee_count)}
  end

  # Handle employee creation
  def handle_info({:created, %{type: :employee, employee: employee_data}}, socket) do
    current_user_id = socket.assigns.current_user.id
    # Check if the employee's company is owned by the current user
    company = Companies.get_company(employee_data.company_id)

    if company && company.owner_id == current_user_id do
      # Re-fetch companies for the current user to get updated employee lists
      companies = Companies.list_companies_by_owner(current_user_id)
      employee_count = calculate_employee_count(companies)
      {:noreply, assign(socket, companies: companies, employee_count: employee_count)}
    else
      {:noreply, socket}
    end
  end

  # Handle employee update
  def handle_info({:updated, %{type: :employee, employee: employee_data}}, socket) do
    current_user_id = socket.assigns.current_user.id
    company = Companies.get_company(employee_data.company_id)

    if company && company.owner_id == current_user_id do
      companies = Companies.list_companies_by_owner(current_user_id)
      employee_count = calculate_employee_count(companies)
      {:noreply, assign(socket, companies: companies, employee_count: employee_count)}
    else
      {:noreply, socket}
    end
  end

  # Handle employee deletion
  def handle_info({:deleted, %{type: :employee, employee: employee_data}}, socket) do
    current_user_id = socket.assigns.current_user.id
    # We need the company_id from the deleted employee data.
    # The broadcast for delete_employee in companies.ex sends the full employee struct.
    company = Companies.get_company(employee_data.company_id)

    if company && company.owner_id == current_user_id do
      companies = Companies.list_companies_by_owner(current_user_id)
      employee_count = calculate_employee_count(companies)
      {:noreply, assign(socket, companies: companies, employee_count: employee_count)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("open_create_company_dialog", _params, socket) do
    handle_open_create_company_dialog(socket)
  end

  def handle_event("create_company", params, socket) do
    handle_create_company(socket, params)
  end

  @impl true
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
                <%= @employee_count %>
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

  defp calculate_employee_count(companies) do
    Enum.reduce(companies, 0, fn company, acc ->
      acc + length(Companies.get_company_employees(company))
    end)
  end
end
