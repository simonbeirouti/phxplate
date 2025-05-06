defmodule PhxplateWeb.Dashboard.Admin.CompanyShowLive do
  use PhxplateWeb, :live_view

  alias Phxplate.Companies

  def mount(%{"id" => company_id}, _session, socket) do
    company = Companies.get_company!(company_id)
    employees = Companies.get_company_employees(company)

    {:ok,
     assign(socket,
       page_title: "#{company.name} Details",
       page_description: "Company details and employee management",
       company: company,
       employees: employees,
       show_edit_modal: false,
       selected_employee: nil
     )}
  end

  def handle_event("edit_employee", %{"id" => employee_id}, socket) do
    employee = Enum.find(socket.assigns.employees, &(&1.id == employee_id))
    {:noreply, assign(socket, show_edit_modal: true, selected_employee: employee)}
  end

  def handle_event("delete_employee", %{"id" => employee_id}, socket) do
    employee = Enum.find(socket.assigns.employees, &(&1.id == employee_id))

    case Companies.delete_employee(employee) do
      {:ok, _} ->
        employees = Companies.get_company_employees(socket.assigns.company)

        {:noreply,
         socket
         |> put_flash(:info, "Employee deleted successfully.")
         |> assign(employees: employees)}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not delete employee.")}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <h2 class="text-2xl font-semibold text-gray-900">{@company.name}</h2>
        <:subtitle>
          {@company.description}
        </:subtitle>
      </.header>

      <.tabs :let={builder} default="profile" id="company-details" class="mt-4 h-[calc(100vh-200px)]">
        <.tabs_list class="grid w-full lg:w-1/2 grid-cols-3">
          <.tabs_trigger builder={builder} value="profile">Profile</.tabs_trigger>
          <.tabs_trigger builder={builder} value="employees">Employees</.tabs_trigger>
          <.tabs_trigger builder={builder} value="timeline">Timeline</.tabs_trigger>
        </.tabs_list>

        <.tabs_content value="profile" class="h-[calc(100vh-250px)]">
          <div class="space-y-4 p-4">
            <div class="grid grid-cols-2 gap-4">
              <div>
                <h4 class="text-sm font-medium text-gray-500">Name</h4>
                <p class="mt-1">{@company.name}</p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500">Email</h4>
                <p class="mt-1">{@company.email}</p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500">Phone</h4>
                <p class="mt-1">{@company.phone}</p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500">Website</h4>
                <p class="mt-1">{@company.website || "Not provided"}</p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500">Plan</h4>
                <p class="mt-1 capitalize">{@company.plan}</p>
              </div>
              <div>
                <h4 class="text-sm font-medium text-gray-500">Logo</h4>
                <p class="mt-1">{@company.logo || "Not provided"}</p>
              </div>
              <div class="col-span-2">
                <h4 class="text-sm font-medium text-gray-500">Address</h4>
                <p class="mt-1">{@company.address}</p>
              </div>
              <div class="col-span-2">
                <h4 class="text-sm font-medium text-gray-500">Description</h4>
                <p class="mt-1">{@company.description || "No description provided"}</p>
              </div>
            </div>
          </div>
        </.tabs_content>

        <.tabs_content value="employees" class="h-[calc(100vh-250px)]">
          <div class="space-y-4">
            <div class="hidden lg:block overflow-x-auto">
              <.table>
                <.table_header>
                  <.table_row>
                    <.table_head>Name</.table_head>
                    <.table_head>Email</.table_head>
                    <.table_head>Phone</.table_head>
                    <.table_head>Position</.table_head>
                    <.table_head>Department</.table_head>
                    <.table_head class="text-right">Actions</.table_head>
                  </.table_row>
                </.table_header>
                <.table_body>
                  <%= for employee <- @employees do %>
                    <.table_row>
                      <.table_cell class="font-medium">
                        {employee.first_name} {employee.last_name}
                      </.table_cell>
                      <.table_cell>{employee.email}</.table_cell>
                      <.table_cell>{employee.phone || "N/A"}</.table_cell>
                      <.table_cell>{employee.position || "N/A"}</.table_cell>
                      <.table_cell>{employee.department || "N/A"}</.table_cell>
                      <.table_cell class="text-right">
                        <.button
                          variant="outline"
                          phx-click="edit_employee"
                          phx-value-id={employee.id}
                        >
                          <Lucideicons.pencil class="h-4 w-4" />
                        </.button>
                        <.button
                          variant="outline"
                          phx-click="delete_employee"
                          phx-value-id={employee.id}
                          data-confirm="Are you sure you want to delete this employee?"
                        >
                          <Lucideicons.trash class="h-4 w-4" />
                        </.button>
                      </.table_cell>
                    </.table_row>
                  <% end %>
                </.table_body>
              </.table>
            </div>

            <div class="lg:hidden space-y-4" class="h-[calc(100vh-250px)]">
              <%= for employee <- @employees do %>
                <div class="bg-white shadow rounded-lg p-4">
                  <div class="flex justify-between items-start mb-4">
                    <div>
                      <h3 class="text-lg font-medium">{employee.first_name} {employee.last_name}</h3>
                      <p class="text-sm text-gray-500">{employee.position || "No position"}</p>
                    </div>
                    <div>
                      <div class="relative inline-block text-left">
                        <.button
                          variant="outline"
                          size="sm"
                          class="mb-2"
                          phx-click={JS.toggle(to: "#dropdown-#{employee.id}-card")}
                        >
                          <Lucideicons.ellipsis class="w-5 h-5" />
                        </.button>
                        <div
                          id={"dropdown-#{employee.id}-card"}
                          class="hidden absolute right-0 w-48 rounded-md shadow-lg bg-white ring-1 ring-black ring-opacity-5 divide-y divide-gray-100"
                        >
                          <div>
                            <button
                              class="group flex w-full items-center px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                              phx-click="edit_employee"
                              phx-value-id={employee.id}
                            >
                              <Lucideicons.pencil class="mr-2 h-4 w-4" /> Edit Employee
                            </button>
                            <button
                              class="group flex w-full items-center px-4 py-2 text-sm text-red-600 hover:bg-gray-100"
                              phx-click="delete_employee"
                              phx-value-id={employee.id}
                              data-confirm="Are you sure you want to delete this employee?"
                            >
                              <Lucideicons.trash class="mr-2 h-4 w-4" /> Delete Employee
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                  <dl class="grid grid-cols-1 gap-2 text-sm">
                    <div>
                      <dt class="text-gray-500">Email</dt>
                      <dd>{employee.email}</dd>
                    </div>
                    <div>
                      <dt class="text-gray-500">Phone</dt>
                      <dd>{employee.phone || "N/A"}</dd>
                    </div>
                    <div>
                      <dt class="text-gray-500">Department</dt>
                      <dd>{employee.department || "N/A"}</dd>
                    </div>
                  </dl>
                </div>
              <% end %>
            </div>
          </div>
        </.tabs_content>

        <.tabs_content value="timeline">
          <div class="space-y-4 p-4">
            <div>
              <h4 class="text-sm font-medium text-gray-500">Created</h4>
              <p class="mt-1">
                {Calendar.strftime(@company.inserted_at, "%B %d, %Y at %I:%M %p")}
              </p>
            </div>
            <div>
              <h4 class="text-sm font-medium text-gray-500">Last Updated</h4>
              <p class="mt-1">
                {Calendar.strftime(@company.updated_at, "%B %d, %Y at %I:%M %p")}
              </p>
            </div>
          </div>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end
end
