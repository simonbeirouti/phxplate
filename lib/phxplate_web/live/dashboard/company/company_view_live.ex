defmodule PhxplateWeb.Dashboard.Company.CompanyViewLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Companies

  def mount(%{"id" => id}, _session, socket) do
    case get_company_data(id, socket.assigns.current_user.email) do
      {:ok, data} ->
        {:ok,
         socket
         |> assign(:page_title, data.company.name)
         |> assign(:company, data.company)}

      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "You don't have access to this company")
         |> redirect(to: ~p"/dashboard")}
    end
  end

  defp get_company_data(id, user_email) do
    with {:ok, id} <- parse_id(id),
         %Companies.Company{} = company <- Companies.get_company!(id),
         true <- is_employee?(company.id, user_email) do
      {:ok, %{company: company}}
    else
      _ -> {:error, :not_found}
    end
  end

  defp parse_id(id) do
    case Integer.parse(id) do
      {id, ""} -> {:ok, id}
      _ -> :error
    end
  end

  defp is_employee?(company_id, email) do
    case Companies.get_employee_by_company_and_email(company_id, email) do
      nil -> false
      _employee -> true
    end
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        <%= @company.name %>
        <:subtitle>Company Information</:subtitle>
      </.header>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2">
        <div class="space-y-2">
          <label class="text-sm font-medium">Name</label>
          <div class="text-gray-700"><%= @company.name %></div>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Description</label>
          <div class="text-gray-700"><%= @company.description %></div>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Address</label>
          <div class="text-gray-700"><%= @company.address %></div>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Phone</label>
          <div class="text-gray-700"><%= @company.phone %></div>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Email</label>
          <div class="text-gray-700"><%= @company.email %></div>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Website</label>
          <div class="text-gray-700">
            <.link href={@company.website} target="_blank" class="text-primary hover:underline">
              <%= @company.website %>
            </.link>
          </div>
        </div>

        <div class="space-y-2">
          <label class="text-sm font-medium">Plan</label>
          <div class="text-gray-700"><%= String.capitalize(@company.plan) %></div>
        </div>
      </div>

      <.header class="mt-8">
        Employees
        <:subtitle>List of all employees in the company</:subtitle>
      </.header>

      <div class="divide-y divide-gray-200">
        <%= for employee <- @company.employees do %>
          <div class="py-4">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-4">
                <div class="flex-shrink-0">
                  <img
                    src={if employee.profile, do: employee.profile.avatar_url || "/images/default-avatar.svg", else: "/images/default-avatar.svg"}
                    alt={employee.first_name}
                    class="w-10 h-10 rounded-full bg-gray-100"
                  />
                </div>
                <div>
                  <div class="text-sm font-medium text-gray-900">
                    <%= employee.first_name %> <%= employee.last_name %>
                  </div>
                  <div class="text-sm text-gray-500">
                    <%= employee.email %>
                  </div>
                </div>
              </div>
              <div class="text-right">
                <div class="text-sm text-gray-900">
                  <%= employee.position || "-" %>
                </div>
                <div class="text-sm text-gray-500">
                  <%= employee.department || "-" %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
