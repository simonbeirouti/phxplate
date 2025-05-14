defmodule PhxplateWeb.Dashboard.SuperAdmin.CompaniesLive do
  use PhxplateWeb, :live_view
  alias Phxplate.{Companies, Repo}
  alias PhxplateWeb.{PageMeta, Components.ActivityTimelineComponent}
  alias Phxplate.PubSub.DataSync

  def mount(_params, _session, socket) do
    if connected?(socket) do
      DataSync.subscribe("companies", "all")
      DataSync.subscribe("employees", "all")
      DataSync.subscribe("profiles", "all")
    end

    socket =
      socket
      |> assign(:selected_company, nil)
      |> assign(:activities, [])
      |> assign(:confirming_delete_company, false)
      |> PageMeta.assign_metadata(
        title: "Companies Management",
        description: "Manage companies across the application"
      )

    {:ok, load_companies(socket, 1)}
  end

  @impl true
  def handle_info({:created, %{type: :company, company: company}}, socket) do
    # Instead of just appending, reload the companies for the current page
    {:noreply, load_companies(socket, socket.assigns.page)}
  end

  def handle_info({:updated, %{type: :company, company: company}}, socket) do
    company = Repo.preload(company, [:employees])

    socket =
      socket
      |> update(:companies, fn companies ->
        Enum.map(companies, fn c -> if c.id == company.id, do: company, else: c end)
      end)
      |> maybe_update_selected_company(company)

    {:noreply, socket}
  end

  def handle_info({:deleted, %{type: :company, id: company_id}}, socket) do
    # Clear selected company if it was deleted
    socket =
      if socket.assigns.selected_company && socket.assigns.selected_company.id == company_id do
        socket
        |> assign(:selected_company, nil)
        |> assign(:activities, [])
        |> assign(:confirming_delete_company, false)
        |> put_flash(:info, "Selected company was deleted.")
      else
        socket
      end

    # Reload the companies list to ensure proper pagination
    {:noreply, load_companies(socket, socket.assigns.page)}
  end

  def handle_info({:deleted, %{type: :employee, employee: employee}}, socket) do
    if socket.assigns.selected_company && employee.company_id == socket.assigns.selected_company.id do
      # Update the selected company's employees list by removing the deleted employee
      socket = update(socket, :selected_company, fn company ->
        %{company | employees: Enum.reject(company.employees, &(&1.id == employee.id))}
      end)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :employee, id: employee_id}}, socket) do
    if socket.assigns.selected_company do
      # Update the selected company's employees list by removing the deleted employee
      socket = update(socket, :selected_company, fn company ->
        %{company | employees: Enum.reject(company.employees, &(&1.id == employee_id))}
      end)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:created, %{type: :employee, employee: employee}}, socket) do
    if socket.assigns.selected_company && employee.company_id == socket.assigns.selected_company.id do
      # Update the selected company's employees list by adding the new employee
      socket = update(socket, :selected_company, fn company ->
        %{company | employees: [employee | company.employees]}
      end)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :profile, profile: profile}}, socket) do
    if socket.assigns.selected_company do
      # Update the employee's profile in the selected company's employees list
      socket = update(socket, :selected_company, fn company ->
        updated_employees = Enum.map(company.employees, fn employee ->
          if employee.profile && employee.profile.id == profile.id do
            %{employee | profile: nil}
          else
            employee
          end
        end)
        %{company | employees: updated_employees}
      end)
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp maybe_update_selected_company(socket, company) do
    if socket.assigns.selected_company && socket.assigns.selected_company.id == company.id do
      assign(socket, :selected_company, company)
    else
      socket
    end
  end

  def handle_event("select_company", %{"id" => company_id}, socket) do
    case Integer.parse(company_id) do
      {id, ""} ->
        try do
          company = Companies.get_company!(id) |> Repo.preload([:employees])
          activities = Phxplate.Tracking.get_company_activities(id, 20)
          {:noreply, assign(socket, selected_company: company, activities: activities)}
        rescue
          Ecto.NoResultsError ->
            {:noreply,
             socket
             |> put_flash(:error, "Company not found or was deleted.")
             |> assign(:selected_company, nil)
             |> assign(:activities, [])}
        end

      _ ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid company ID format.")
         |> assign(:selected_company, nil)
         |> assign(:activities, [])}
    end
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    {:noreply, load_companies(socket, page)}
  end

  def handle_params(params, _uri, socket) do
    page =
      case params["page"] do
        nil -> 1
        page_param -> String.to_integer(page_param)
      end

    {:noreply, load_companies(socket, page)}
  end

  def handle_event("confirm_delete_company", _params, socket) do
    {:noreply, assign(socket, :confirming_delete_company, true)}
  end

  def handle_event("delete_company", _params, socket) do
    case Companies.delete_company(socket.assigns.selected_company) do
      {:ok, _deleted_company} ->
        {:noreply,
         socket
         |> assign(:selected_company, nil)
         |> assign(:confirming_delete_company, false)
         |> put_flash(:info, "Company deleted successfully.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete company.")
         |> assign(:confirming_delete_company, false)}
    end
  end

  defp load_companies(socket, page) do
    per_page = 10

    # Get total count for pagination
    total_companies = Companies.count_companies()
    total_pages = max(1, ceil(total_companies / per_page))

    # Get paginated companies
    companies =
      Companies.list_companies(page: page, per_page: per_page)
      |> Repo.preload([:employees])

    socket
    |> assign(:companies, companies)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:per_page, per_page)
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Companies Management
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
                  <Lucideicons.arrow_right class="w-5 h-5 mr-2" />
                </div>
              </div>
            <% end %>
          </div>

          <%= if @total_pages > 1 do %>
            <div class="mt-6">
              <.pagination>
                <.pagination_content class="w-full flex justify-center items-center">
                  <%= if @page > 1 do %>
                    <.pagination_item>
                      <.pagination_link phx-click="paginate" phx-value-page={@page - 1}>
                        <Lucideicons.arrow_left class="w-3.5 h-3.5" />
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>

                  <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                    <.pagination_item>
                      <.pagination_link
                        phx-click="paginate"
                        phx-value-page={page_num}
                        is-active={page_num == @page}
                      >
                        {page_num}
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>

                  <%= if @page < @total_pages do %>
                    <.pagination_item>
                      <.pagination_link phx-click="paginate" phx-value-page={@page + 1}>
                        <Lucideicons.arrow_right class="w-3.5 h-3.5" />
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>
                </.pagination_content>
              </.pagination>
            </div>
          <% end %>
        </div>

        <div class="col-span-3 md:col-span-2">
          <h2 class="text-xl font-semibold mb-4">Company Details</h2>
          <%= if @selected_company do %>
            <.tabs :let={builder} default="details" id="company-details">
              <.tabs_list class="grid w-full grid-cols-3">
                <.tabs_trigger builder={builder} value="details">Details</.tabs_trigger>
                <.tabs_trigger builder={builder} value="employees">Employees</.tabs_trigger>
                <.tabs_trigger builder={builder} value="timeline">Timeline</.tabs_trigger>
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
                        <a
                          href={@selected_company.website}
                          target="_blank"
                          class="text-primary-600 hover:text-primary-700"
                        >
                          {@selected_company.website}
                        </a>
                      <% else %>
                        No website provided
                      <% end %>
                    </p>
                  </div>
                  <div class="pt-4 border-t">
                    <.button
                      :if={!@confirming_delete_company}
                      type="button"
                      variant="destructive"
                      phx-click="confirm_delete_company"
                    >
                      Delete Company
                    </.button>
                    <.button
                      :if={@confirming_delete_company}
                      type="button"
                      variant="destructive"
                      phx-click="delete_company"
                    >
                      Confirm Delete
                    </.button>
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
                              <p class="font-medium">{employee.profile.first_name} {employee.profile.last_name}</p>
                              <p class="text-sm text-gray-500">{employee.email}</p>
                              <p class="text-sm text-gray-500">Position: {employee.position}</p>
                              <p class="text-sm text-gray-500">Department: {employee.department}</p>
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

              <.tabs_content value="timeline">
                <%= if @selected_company do %>
                  <.live_component
                    module={ActivityTimelineComponent}
                    id={"activity-timeline-#{@selected_company.id}"}
                    activities={@activities}
                    company_id={@selected_company.id}
                    show_timestamps={true}
                    timestamps={%{
                      inserted_at: @selected_company.inserted_at,
                      updated_at: @selected_company.updated_at
                    }}
                  />
                <% end %>
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
