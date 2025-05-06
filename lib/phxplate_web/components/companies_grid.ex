defmodule PhxplateWeb.Components.CompaniesGrid do
  use Phoenix.Component
  alias Phxplate.Companies

  attr :companies, :list, required: true
  attr :subscription, :map, required: true
  attr :on_create, :any, required: true

  defp get_company_limit(subscription) do
    case subscription do
      nil ->
        0

      %{plan: nil} ->
        0

      %{plan: plan} ->
        case plan.features["projects"] do
          "Unlimited" -> 999_999
          limit when is_integer(limit) -> limit
          _ -> 0
        end
    end
  end

  def companies_grid(assigns) do
    company_limit = get_company_limit(assigns.subscription)
    can_create_company = length(assigns.companies) < company_limit
    assigns = assign(assigns,
      company_limit: company_limit,
      can_create_company: can_create_company
    )

    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mt-4">
      <%= for company <- assigns.companies do %>
        <div class="bg-white shadow rounded-lg p-4 flex flex-col justify-center">
          <h3 class="text-lg font-semibold text-gray-900 mb-2"><%= company.name %></h3>
          <p class="text-gray-600 mb-3">
            <%= length(Companies.get_company_employees(company)) %> Employees
          </p>
          <.link
            navigate={"/dashboard/admin/company/#{company.id}"}
            class="text-blue-600 hover:text-blue-800 font-medium"
          >
            View Details →
          </.link>
        </div>
      <% end %>

      <%= if @can_create_company do %>
        <div
          class="bg-white rounded-lg p-4 border-2 border-dashed border-gray-300 flex flex-col items-center justify-center hover:border-gray-400 transition-colors cursor-pointer"
          phx-click={@on_create}
        >
          <Lucideicons.plus class="w-10 h-10 bg-blue-50 rounded-full p-2 text-blue-600 mb-2" />
          <h3 class="text-base font-medium text-gray-900">Create New Company</h3>
          <p class="text-sm text-gray-500 text-center mt-1">
            Click to add a new company to your dashboard.
          </p>
          <p class="text-sm text-gray-500 text-center mt-1">
            You can create up to <%= if @company_limit >= 999_999, do: "∞", else: @company_limit %> companies.
          </p>
        </div>
      <% end %>
    </div>
    """
  end
end
