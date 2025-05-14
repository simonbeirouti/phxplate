defmodule PhxplateWeb.Dashboard.Admin.CompanyShowLive do
  use PhxplateWeb, :live_view

  alias Phxplate.Companies
  alias PhxplateWeb.Components.ActivityTimelineComponent
  alias PhxplateWeb.Components.ImageUploadComponent
  alias PhxplateWeb.Authorization
  alias Phxplate.PubSub.DataSync
  alias Phxplate.Repo

  @impl true
  def on_mount(:default, %{"id" => company_id}, _session, socket) do
    case authorize_company(company_id, socket.assigns.current_user) do
      {:ok, _company} -> {:cont, socket}
      {:error, _reason} ->
        {:halt,
         socket
         |> put_flash(:error, "You don't have access to this company")
         |> redirect(to: ~p"/dashboard/admin/companies")}
    end
  end

  def on_mount(:default, _params, _session, socket), do: {:cont, socket}

  @impl true
  def mount(%{"id" => company_id}, _session, socket) do
    if connected?(socket) do
      DataSync.subscribe("companies", company_id)
      DataSync.subscribe("employees", company_id)
      DataSync.subscribe("invitations", company_id)
      DataSync.subscribe("users", "all")
      DataSync.subscribe("profiles", "all")
    end

    case authorize_company(company_id, socket.assigns.current_user) do
      {:ok, company} ->
        employees = Companies.get_company_employees(company)
        activities = Phxplate.Tracking.get_company_activities(company_id)
        pending_invitations = Companies.list_pending_invitations(company)

        socket =
          socket
          |> assign(
            page_title: "#{company.name} Details",
            page_description: "Company details and employee management",
            company: company,
            form:
              to_form(%{
                "name" => company.name,
                "email" => company.email,
                "phone" => company.phone,
                "website" => company.website,
                "plan" => company.plan,
                "address" => company.address,
                "description" => company.description,
                "logo" => company.logo
              }),
            employees: employees,
            activities: activities,
            show_edit_modal: false,
            selected_employee: nil,
            confirming_delete: MapSet.new(),
            invite_email: "",
            form_changed: false,
            pending_invitations: pending_invitations,
            confirming_delete_company: false
          )

        {:ok, socket}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have access to this company")
         |> redirect(to: ~p"/dashboard/admin/companies")}
    end
  end

  @impl true
  def handle_info({:created, %{type: :employee, employee: new_employee}}, socket) do
    # The 'new_employee' from PubSub (e.g., from accept_invitation)
    # should already have its profile preloaded.
    # Check if an employee with this ID already exists in our current list.
    is_present = Enum.any?(socket.assigns.employees, fn existing_employee ->
      existing_employee.id == new_employee.id
    end)

    if is_present do
      # Employee is already in the list. Do nothing to prevent duplication.
      # Optionally, one could update the existing entry with new_employee data here
      # if there's a chance it might be fresher, but for a :created event,
      # simply avoiding duplication is the primary goal.
      {:noreply, socket}
    else
      # Employee is not in the list, so prepend it.
      {:noreply, update(socket, :employees, fn existing_employees ->
        [new_employee | existing_employees]
      end)}
    end
  end

  def handle_info({:updated, %{type: :employee, employee: employee}}, socket) do
    employee = Repo.preload(employee, [:profile])
    {:noreply,
     update(socket, :employees, fn employees ->
       Enum.map(employees, fn e -> if e.id == employee.id, do: employee, else: e end)
     end)}
  end

  def handle_info({:deleted, %{type: :employee, id: employee_id}}, socket) do
    updated_employees = Enum.reject(socket.assigns.employees, fn employee ->
      employee.id == employee_id
    end)

    {:noreply, assign(socket, :employees, updated_employees)}
  end

  def handle_info({:created, %{type: :invitation, invitation: invitation}}, socket) do
    invitation = Repo.preload(invitation, [:company, :inviter])
    {:noreply,
     update(socket, :pending_invitations, fn invitations -> [invitation | invitations] end)}
  end

  def handle_info({:updated, %{type: :invitation, invitation: invitation}}, socket) do
    invitation = Repo.preload(invitation, [:company, :inviter])
    {:noreply,
     update(socket, :pending_invitations, fn invitations ->
       Enum.map(invitations, fn inv -> if inv.id == invitation.id, do: invitation, else: inv end)
     end)}
  end

  def handle_info({:deleted, %{type: :invitation, id: invitation_id}}, socket) do
    {:noreply,
     update(socket, :pending_invitations, fn invitations ->
       Enum.reject(invitations, &(&1.id == invitation_id))
     end)}
  end

  def handle_info({:updated, %{type: :company, company: company}}, socket) do
    activities = Phxplate.Tracking.get_company_activities(company.id)

    {:noreply,
     socket
     |> assign(:company, company)
     |> assign(:activities, activities)
     |> assign(
       :form,
       to_form(%{
         "name" => company.name,
         "email" => company.email,
         "phone" => company.phone,
         "website" => company.website,
         "plan" => company.plan,
         "address" => company.address,
         "description" => company.description,
         "logo" => company.logo
       })
     )}
  end

  def handle_info({:deleted, %{type: :company, id: company_id}}, socket) do
    if socket.assigns.company.id == company_id do
      {:noreply,
       socket
       |> put_flash(:error, "Company was deleted.")
       |> redirect(to: ~p"/dashboard/admin/companies")}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :user, id: user_id}}, socket) do
    # Find employees associated with the deleted user
    employees_to_delete = Enum.filter(socket.assigns.employees, fn employee ->
      employee.profile && employee.profile.user_id == user_id
    end)

    # Delete each employee
    Enum.each(employees_to_delete, fn employee ->
      Companies.delete_employee(employee, socket.assigns.current_user)
    end)

    # Remove the employees from the view and refresh activities
    updated_employees = Enum.reject(socket.assigns.employees, fn employee ->
      employee.profile && employee.profile.user_id == user_id
    end)

    activities = Phxplate.Tracking.get_company_activities(socket.assigns.company.id)

    {:noreply,
     socket
     |> assign(:employees, updated_employees)
     |> assign(:activities, activities)}
  end

  def handle_info({:deleted, %{type: :profile, id: profile_id}}, socket) do
    # Remove employees with deleted profiles
    updated_employees = Enum.reject(socket.assigns.employees, fn employee ->
      employee.profile && employee.profile.id == profile_id
    end)

    activities = Phxplate.Tracking.get_company_activities(socket.assigns.company.id)

    {:noreply,
     socket
     |> assign(:employees, updated_employees)
     |> assign(:activities, activities)}
  end

  def handle_info({:deleted, %{type: :employee, employee: employee}}, socket) do
    # Remove the specific employee from the view
    updated_employees = Enum.reject(socket.assigns.employees, fn e ->
      e.id == employee.id
    end)

    activities = Phxplate.Tracking.get_company_activities(socket.assigns.company.id)

    {:noreply,
     socket
     |> assign(:employees, updated_employees)
     |> assign(:activities, activities)}
  end

  def handle_info({:employee_deleted, %{type: :employee, id: employee_id}}, socket) do
    # Remove the specific employee from the view
    updated_employees = Enum.reject(socket.assigns.employees, fn employee ->
      employee.id == employee_id
    end)

    activities = Phxplate.Tracking.get_company_activities(socket.assigns.company.id)

    {:noreply,
     socket
     |> assign(:employees, updated_employees)
     |> assign(:activities, activities)}
  end

  # Handle global profile creation events
  def handle_info({:created, %{type: :profile, profile: new_profile, global_scope: true}}, socket) do
    updated_employees = Enum.map(socket.assigns.employees, fn employee ->
      # If employee is linked by user_id and this new_profile is for that user
      if employee.profile_id == nil && employee.user_id == new_profile.user_id do
        %{employee | profile: new_profile, profile_id: new_profile.id}
      else
        employee
      end
    end)
    {:noreply, assign(socket, :employees, updated_employees)}
  end

  # Handle global profile update events that CompanyShowLive might receive
  def handle_info({:updated, %{type: :profile, profile: updated_profile, global_scope: true}}, socket) do
    updated_employees = Enum.map(socket.assigns.employees, fn employee ->
      cond do
        # Profile exists and IDs match
        employee.profile && employee.profile.id == updated_profile.id ->
          %{employee | profile: updated_profile}
        # Profile was nil, but profile_id matches (should ideally not happen if preloaded correctly but good fallback)
        !employee.profile && employee.profile_id == updated_profile.id ->
           %{employee | profile: updated_profile}
        # Employee is linked by user_id and this updated_profile is for that user
        employee.user_id == updated_profile.user_id ->
           %{employee | profile: updated_profile, profile_id: updated_profile.id}
        true ->
          employee
      end
    end)
    {:noreply, assign(socket, :employees, updated_employees)}
  end

  defp authorize_company(company_id, user) do
    with {:ok, id} <- parse_id(company_id),
         %Companies.Company{} = company <- Companies.get_company!(id),
         true <- Authorization.is_company_owner?(company, user) do
      {:ok, company}
    else
      _ -> {:error, :unauthorized}
    end
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  @impl true
  def handle_event("validate_company", params, socket) do
    form_data = %{
      "name" => socket.assigns.company.name,
      "email" => socket.assigns.company.email,
      "phone" => socket.assigns.company.phone,
      "website" => socket.assigns.company.website,
      "plan" => socket.assigns.company.plan,
      "address" => socket.assigns.company.address,
      "description" => socket.assigns.company.description,
      "logo" => socket.assigns.company.logo
    }

    form_changed = params != form_data

    {:noreply,
     socket
     |> assign(:form, to_form(params))
     |> assign(:form_changed, form_changed)}
  end

  def handle_event("save_company", params, socket) do
    case Companies.update_company(socket.assigns.company, params, socket.assigns.current_user) do
      {:ok, company} ->
        activities = Phxplate.Tracking.get_company_activities(company.id)

        {:noreply,
         socket
         |> assign(:company, company)
         |> assign(:activities, activities)
         |> assign(
           :form,
           to_form(%{
             "name" => company.name,
             "email" => company.email,
             "phone" => company.phone,
             "website" => company.website,
             "plan" => company.plan,
             "address" => company.address,
             "description" => company.description,
             "logo" => company.logo
           })
         )
         |> assign(:form_changed, false)
         |> put_flash(:info, "Company updated successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> put_flash(:error, "Error updating company.")}
    end
  end

  def handle_event("reset_company", _params, socket) do
    {:noreply,
     socket
     |> assign(
       :form,
       to_form(%{
         "name" => socket.assigns.company.name,
         "email" => socket.assigns.company.email,
         "phone" => socket.assigns.company.phone,
         "website" => socket.assigns.company.website,
         "plan" => socket.assigns.company.plan,
         "address" => socket.assigns.company.address,
         "description" => socket.assigns.company.description,
         "logo" => socket.assigns.company.logo
       })
     )
     |> assign(:form_changed, false)}
  end

  def handle_event("edit_employee", %{"id" => employee_id}, socket) do
    employee = Enum.find(socket.assigns.employees, &(&1.id == employee_id))
    {:noreply, assign(socket, show_edit_modal: true, selected_employee: employee)}
  end

  def handle_event("open_invite_dialog", _params, socket) do
    {:noreply,
     socket
     |> assign(:invite_email, "")
     |> push_event("reset-form", %{id: "invite-form"})}
  end

  def handle_event("send_invite", %{"email" => email}, socket) do
    case Companies.invite_to_company(socket.assigns.company, email, socket.assigns.current_user) do
      {:ok, _invitation} ->
        activities = Phxplate.Tracking.get_company_activities(socket.assigns.company.id)

        {:noreply,
         socket
         |> assign(:activities, activities)
         |> assign(:invite_email, "")
         |> push_event("reset-form", %{id: "invite-form"})
         |> put_flash(:info, "Invitation sent successfully to #{email}")
         |> push_event("hide-modal", %{id: "invite-user-dialog"})}

      {:error, %Ecto.Changeset{} = changeset} ->
        error_message =
          case changeset.errors do
            [{:email, {msg, _}}] -> msg
            [{:company_id, {msg, _}}] -> msg
            _ -> "Failed to send invitation. Please try again."
          end

        {:noreply,
         socket
         |> put_flash(:error, error_message)
         |> assign(:invite_email, email)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to send invitation. Please try again.")
         |> assign(:invite_email, email)}
    end
  end

  def handle_event("delete_employee", %{"id" => employee_id}, socket) do
    # Convert employee_id to integer since it comes as string from the template
    employee_id = String.to_integer(employee_id)

    if MapSet.member?(socket.assigns.confirming_delete, employee_id) do
      employee = Enum.find(socket.assigns.employees, &(&1.id == employee_id))

      case Companies.delete_employee(employee, socket.assigns.current_user) do
        {:ok, _deleted_employee} ->
          employees = Companies.get_company_employees(socket.assigns.company)
          activities = Phxplate.Tracking.get_company_activities(socket.assigns.company.id)

          {:noreply,
           socket
           |> assign(:employees, employees)
           |> assign(:activities, activities)
           |> assign(
             :confirming_delete,
             MapSet.delete(socket.assigns.confirming_delete, employee_id)
           )
           |> put_flash(:info, "Employee deleted successfully.")}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(
             :confirming_delete,
             MapSet.delete(socket.assigns.confirming_delete, employee_id)
           )
           |> put_flash(:error, "Could not delete employee.")}
      end
    else
      {:noreply,
       assign(socket,
         confirming_delete: MapSet.put(socket.assigns.confirming_delete, employee_id)
       )}
    end
  end

  def handle_event("cancel_invitation", %{"id" => invitation_id}, socket) do
    invitation_id = String.to_integer(invitation_id)
    invitation = Enum.find(socket.assigns.pending_invitations, &(&1.id == invitation_id))

    case Companies.delete_invitation(invitation) do
      {:ok, _deleted_invitation} ->
        pending_invitations = Companies.list_pending_invitations(socket.assigns.company)
        activities = Phxplate.Tracking.get_company_activities(socket.assigns.company.id)

        {:noreply,
         socket
         |> assign(:pending_invitations, pending_invitations)
         |> assign(:activities, activities)
         |> put_flash(:info, "Invitation canceled successfully.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not cancel invitation.")}
    end
  end

  @impl true
  def handle_info({:image_uploaded, %{type: :logo, url: url}}, socket) do
    case Companies.update_company(
           socket.assigns.company,
           %{"logo" => url},
           socket.assigns.current_user
         ) do
      {:ok, company} ->
        activities = Phxplate.Tracking.get_company_activities(company.id)

        {:noreply,
         socket
         |> assign(:company, company)
         |> assign(:activities, activities)
         |> assign(
           :form,
           to_form(%{
             "name" => company.name,
             "email" => company.email,
             "phone" => company.phone,
             "website" => company.website,
             "plan" => company.plan,
             "address" => company.address,
             "description" => company.description,
             "logo" => company.logo
           })
         )
         |> put_flash(:info, "Company logo updated successfully.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update company logo.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        {@company.name}
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
            <div class="flex justify-center">
              <.live_component
                module={ImageUploadComponent}
                id="company-logo"
                type={:logo}
                image_url={@form[:logo].value}
              />
            </div>
            <.form
              for={@form}
              phx-change="validate_company"
              phx-submit="save_company"
              class="space-y-8"
            >
              <div class="grid grid-cols-2 gap-4">
                <div class="col-span-2 sm:col-span-1 space-y-2">
                  <.label for="company_name">Name</.label>
                  <.input field={@form[:name]} type="text" />
                </div>
                <div class="col-span-2 sm:col-span-1 space-y-2">
                  <.label for="company_email">Email</.label>
                  <.input field={@form[:email]} type="email" />
                </div>
                <div class="col-span-2 sm:col-span-1 space-y-2">
                  <.label for="company_phone">Phone</.label>
                  <.input field={@form[:phone]} type="tel" />
                </div>
                <div class="col-span-2 sm:col-span-1 space-y-2">
                  <.label for="company_website">Website</.label>
                  <.input field={@form[:website]} type="url" />
                </div>
                <div class="col-span-2 sm:col-span-1 space-y-2">
                  <.label for="company_plan">Plan</.label>
                  <.input field={@form[:plan]} type="text" />
                </div>
                <div class="col-span-2 sm:col-span-1 space-y-2">
                  <.label for="company_address">Address</.label>
                  <.input field={@form[:address]} type="text" />
                </div>
                <div class="col-span-2 space-y-2">
                  <.label for="company_description">Description</.label>
                  <.input field={@form[:description]} type="textarea" />
                </div>
              </div>
              <div class="flex justify-between gap-4">
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
                <div class="flex gap-4">
                  <.button :if={@form_changed} type="button" variant="outline" phx-click="reset_company">
                    Reset
                  </.button>
                  <.button :if={@form_changed} type="submit">Save Changes</.button>
                </div>
              </div>
            </.form>
          </div>
        </.tabs_content>

        <.tabs_content value="employees" class="h-[calc(100vh-250px)]">
          <div class="space-y-4">
            <div class="hidden lg:block overflow-x-auto">
              <.table>
                <.table_header>
                  <.table_row>
                    <.table_head>Photo</.table_head>
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
                      <.table_cell>
                        <div class="flex items-center gap-2">
                          <img
                            src={if employee.profile, do: employee.profile.avatar_url || "/images/default-avatar.svg", else: "/images/default-avatar.svg"}
                            alt="Employee avatar"
                            class="w-12 h-12 rounded-full bg-gray-200"
                          />
                        </div>
                      </.table_cell>
                      <.table_cell class="font-medium">
                        {if employee.profile do
                          "#{employee.profile.first_name} #{employee.profile.last_name}"
                        else
                          "Profile Deleted"
                        end}
                      </.table_cell>
                      <.table_cell>{employee.email}</.table_cell>
                      <.table_cell>{if employee.profile, do: employee.profile.phone || "N/A", else: "N/A"}</.table_cell>
                      <.table_cell>{employee.position || "N/A"}</.table_cell>
                      <.table_cell>{employee.department || "N/A"}</.table_cell>
                      <.table_cell class="text-right">
                        <.button
                          variant="destructive"
                          phx-click="delete_employee"
                          phx-value-id={employee.id}
                        >
                          <%= if MapSet.member?(@confirming_delete, employee.id) do %>
                            <Lucideicons.check class="h-4 w-4" />
                          <% else %>
                            <Lucideicons.trash class="h-4 w-4" />
                          <% end %>
                        </.button>
                      </.table_cell>
                    </.table_row>
                  <% end %>
                  <%= for invitation <- @pending_invitations do %>
                    <.table_row class="bg-black/10">
                      <.table_cell class="font-medium">
                        <div class="flex items-center gap-2">
                          <span class="text-sm text-gray-700">Pending Invite</span>
                        </div>
                      </.table_cell>
                      <.table_cell>{invitation.email}</.table_cell>
                      <.table_cell>N/A</.table_cell>
                      <.table_cell>N/A</.table_cell>
                      <.table_cell>N/A</.table_cell>
                      <.table_cell class="text-right">
                        <.button
                          variant="destructive"
                          phx-click="cancel_invitation"
                          phx-value-id={invitation.id}
                        >
                          Cancel Invitation
                        </.button>
                      </.table_cell>
                    </.table_row>
                  <% end %>
                </.table_body>
              </.table>
              <div class="w-1/4">
                <.invite_user_dialog invite_email={@invite_email} />
              </div>
            </div>

            <div class="lg:hidden space-y-4" class="h-[calc(100vh-250px)]">
              <.invite_user_dialog invite_email={@invite_email} />
              <%= for invitation <- @pending_invitations do %>
                <div class="bg-gray-100/80 rounded-lg p-4 relative">
                  <div class="flex justify-between items-center">
                    <div>
                      <span class="text-sm font-medium text-gray-700">Pending Invitation:</span>
                      <span class="text-sm text-gray-600">{invitation.email}</span>
                    </div>
                    <div
                      class="group relative"
                      phx-click="cancel_invitation"
                      phx-value-id={invitation.id}
                    >
                      <.button
                        variant="destructive"
                        class="opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        Cancel Invitation
                      </.button>
                    </div>
                  </div>
                </div>
              <% end %>
              <%= for employee <- @employees do %>
                <div class="bg-white shadow rounded-lg p-4">
                  <div class="flex justify-between items-start mb-4">
                    <div>
                      <h3 class="text-lg font-medium">
                        {if employee.profile do
                          "#{employee.profile.first_name} #{employee.profile.last_name}"
                        else
                          "Profile Deleted"
                        end}
                      </h3>
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
                          <button
                            class="group flex w-full items-center px-4 py-2 text-sm text-red-600 hover:bg-gray-100"
                            phx-click="delete_employee"
                            phx-value-id={employee.id}
                          >
                            <%= if MapSet.member?(@confirming_delete, employee.id) do %>
                              <Lucideicons.check class="mr-2 h-4 w-4" /> Confirm Delete
                            <% else %>
                              <Lucideicons.trash class="mr-2 h-4 w-4" /> Delete Employee
                            <% end %>
                          </button>
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
                      <dd>{if employee.profile, do: employee.profile.phone || "N/A", else: "N/A"}</dd>
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
          <.live_component
            module={ActivityTimelineComponent}
            id={"activity-timeline-#{@company.id}"}
            activities={@activities}
            company_id={@company.id}
            show_timestamps={true}
            timestamps={
              %{
                inserted_at: @company.inserted_at,
                updated_at: @company.updated_at
              }
            }
          />
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  defp invite_user_dialog(assigns) do
    assigns = assign_new(assigns, :invite_email, fn -> "" end)

    ~H"""
    <div class="mt-4" id="invite-user-container" phx-hook="Modal">
      <.button
        class="w-full"
        variant="outline"
        phx-click={
          JS.push("open_invite_dialog")
          |> JS.show(to: "#invite-user-dialog")
        }
      >
        <Lucideicons.plus class="w-4 h-4 mr-2" /> Invite User
      </.button>
      <.dialog id="invite-user-dialog" show={false} on_cancel={JS.hide(to: "#invite-user-dialog")}>
        <div class="relative grid gap-4 border-none p-2">
          <form id="invite-form" phx-submit="send_invite" class="space-y-4" phx-hook="ResetForm">
            <div class="flex flex-col">
              <.label for="email">
                Email
              </.label>
              <.input
                id="email"
                name="email"
                type="email"
                value={@invite_email}
                placeholder="user@example.com"
                required
              />
            </div>
            <.dialog_footer class="flex flex-col gap-2">
              <.button type="submit" class="w-full">Send Invite</.button>
              <.button
                variant="outline"
                type="button"
                phx-click={JS.hide(to: "#invite-user-dialog")}
                class="w-full"
              >
                Cancel
              </.button>
            </.dialog_footer>
          </form>
        </div>
      </.dialog>
    </div>
    """
  end

  def handle_event("confirm_delete_company", _params, socket) do
    {:noreply, assign(socket, :confirming_delete_company, true)}
  end

  def handle_event("delete_company", _params, socket) do
    case Companies.delete_company(socket.assigns.company) do
      {:ok, _deleted_company} ->
        {:noreply,
         socket
         |> put_flash(:info, "Company deleted successfully.")
         |> redirect(to: ~p"/dashboard/admin/companies")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to delete company.")
         |> assign(:confirming_delete_company, false)}
    end
  end
end
