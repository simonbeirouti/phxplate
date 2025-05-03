defmodule PhxplateWeb.Dashboard.SuperAdmin.CompaniesLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Companies, Repo}
  alias PhxplateWeb.PageMeta
  alias PhxplateWeb.Components.UI.Tabs
  import Tabs

  def mount(_params, _session, socket) do
    companies =
      Companies.list_companies()
      |> Repo.preload([:employees])

    {:ok,
     socket
     |> assign(:companies, companies)
     |> assign(:selected_company, nil)
     |> PageMeta.assign_metadata(
       title: "Companies Management",
       description: "Manage companies across the application"
     )}
  end

  def handle_event("select_company", %{"id" => company_id}, socket) do
    company = Companies.get_company!(company_id) |> Repo.preload([:employees])
    {:noreply, assign(socket, selected_company: company)}
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <h1>Companies Management</h1>
        <:subtitle>Manage companies across the application</:subtitle>
      </.header>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-8 mt-4 h-[calc(100vh-200px)]">
        <div class="h-[calc(100vh-200px)] col-span-3 md:col-span-1">
          <h2 class="text-xl font-semibold mb-4">Company List</h2>
          <div class="divide-y">
            <%= for company <- @companies do %>
              <div
                class="py-4 cursor-pointer hover:bg-gray-50 transition-colors"
                phx-click="select_company"
                phx-value-id={company.id}
              >
                <div class="flex items-center justify-between">
                  <div>
                    <p class="font-medium">{company.name}</p>
                    <p class="text-sm text-gray-500">Plan: {company.plan}</p>
                  </div>
                  <span class="text-gray-400">&rarr;</span>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="col-span-3 md:col-span-2">
          <h2 class="text-xl font-semibold mb-4">Company Details</h2>
          <%= if @selected_company do %>
            <.tabs :let={builder} default="details" id="company-details">
              <.tabs_list class="grid w-full grid-cols-3">
                <.tabs_trigger builder={builder} value="details">Details</.tabs_trigger>
                <.tabs_trigger builder={builder} value="employees">Employees</.tabs_trigger>
                <.tabs_trigger builder={builder} value="subscription">Subscription</.tabs_trigger>
              </.tabs_list>

              <.tabs_content value="details">
                <div class="space-y-4 p-4">
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Company Name</h4>
                    <p class="mt-1">{@selected_company.name}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Description</h4>
                    <p class="mt-1">{@selected_company.description || "No description provided"}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Contact Email</h4>
                    <p class="mt-1">{@selected_company.email || "No email provided"}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Phone</h4>
                    <p class="mt-1">{@selected_company.phone || "No phone provided"}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Address</h4>
                    <p class="mt-1">{@selected_company.address || "No address provided"}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Website</h4>
                    <p class="mt-1">
                      <%= if @selected_company.website do %>
                        <a href={@selected_company.website} target="_blank" class="text-primary-600 hover:text-primary-700">
                          {@selected_company.website}
                        </a>
                      <% else %>
                        No website provided
                      <% end %>
                    </p>
                  </div>
                </div>
              </.tabs_content>

              <.tabs_content value="employees">
                <div class="space-y-4 p-4">
                  <%= if Enum.any?(@selected_company.employees) do %>
                    <div class="divide-y">
                      <%= for employee <- @selected_company.employees do %>
                        <div class="py-4">
                          <div class="flex items-center justify-between">
                            <div>
                              <p class="font-medium"><%= employee.first_name %> <%= employee.last_name %></p>
                              <p class="text-sm text-gray-500"><%= employee.email %></p>
                              <p class="text-sm text-gray-500">Position: <%= employee.position %></p>
                              <p class="text-sm text-gray-500">Department: <%= employee.department %></p>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% else %>
                    <p class="text-gray-500">No employees found for this company</p>
                  <% end %>
                </div>
              </.tabs_content>

              <.tabs_content value="subscription">
                <div class="space-y-4 p-4">
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Current Plan</h4>
                    <p class="mt-1">{String.capitalize(@selected_company.plan)}</p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Created</h4>
                    <p class="mt-1">
                      {Calendar.strftime(@selected_company.inserted_at, "%B %d, %Y at %I:%M %p")}
                    </p>
                  </div>
                  <div>
                    <h4 class="text-sm font-medium text-gray-500">Last Updated</h4>
                    <p class="mt-1">
                      {Calendar.strftime(@selected_company.updated_at, "%B %d, %Y at %I:%M %p")}
                    </p>
                  </div>
                </div>
              </.tabs_content>
            </.tabs>
          <% else %>
            <p class="text-gray-500">Select a company to view details</p>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
