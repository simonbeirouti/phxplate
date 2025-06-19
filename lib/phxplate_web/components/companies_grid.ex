defmodule PhxplateWeb.Components.CompaniesGrid do
  @moduledoc """
  Provides a grid component for displaying companies with creation capabilities.

  This component renders a grid of company cards with company information and
  a card to create new companies if the user has not reached their subscription limit.
  It includes a modal dialog for creating new companies.
  """
  use Phoenix.Component
  use PhxplateWeb, :verified_routes
  alias Phxplate.Companies
  alias Phoenix.LiveView.JS
  import PhxplateWeb.Components.UI.DialogDrawerWrapper
  import PhxplateWeb.Components.UI.Input
  import PhxplateWeb.Components.UI.Textarea
  import PhxplateWeb.Components.UI.Button

  attr :companies, :list, required: true, doc: "List of companies to display"

  attr :subscription, :map,
    required: true,
    doc: "The user's subscription to determine company limits"

  attr :on_create, :any, required: true, doc: "The event to trigger when creating a new company"

  attr :show_dialog, :boolean, default: false, doc: "Whether to show the create company dialog"

  attr :mode, :string, default: "dialog", doc: "The mode of the dialog (dialog or drawer)"

  @doc """
  Renders a grid of company cards with a create option if allowed by subscription.

  Calculates whether the user can create more companies based on their subscription plan
  and renders a grid with existing companies and optionally a card to create a new one.
  """
  def companies_grid(assigns) do
    company_limit = get_company_limit(assigns.subscription)
    can_create_company = length(assigns.companies) < company_limit

    assigns =
      assign(assigns,
        company_limit: company_limit,
        can_create_company: can_create_company
      )

    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mt-4">
      <%= for company <- @companies do %>
        <.link navigate={"/dashboard/admin/companies/#{company.id}"}>
          <div class="bg-white shadow rounded-lg p-4 flex flex-col justify-center h-40">
            <h3 class="text-lg font-semibold text-gray-900 mb-2">{company.name}</h3>
            <p class="text-gray-600 mb-3">
              {length(Companies.get_company_employees(company))} Employees
            </p>
            <p class="text-blue-600 hover:text-blue-800 font-medium">
              View Details →
            </p>
          </div>
        </.link>
      <% end %>

      <%= if @can_create_company do %>
        <div
          class="bg-white rounded-lg p-4 border-2 border-dashed border-gray-300 flex flex-col items-center justify-center hover:border-gray-400 transition-colors cursor-pointer h-40"
          phx-click={JS.push("open_create_company_dialog")}
        >
          <Lucideicons.plus class="w-10 h-10 bg-blue-50 rounded-full p-2 text-blue-600 mb-2" />
          <h3 class="text-base font-medium text-gray-900">Create New Company</h3>
          <p class="text-sm text-gray-500 text-center mt-1">
            Click to add a new company to your dashboard.
          </p>
          <p class="text-sm text-gray-500 text-center mt-1">
            You can create up to {if @company_limit >= 999_999, do: "∞", else: @company_limit} companies.
          </p>
        </div>
      <% end %>
    </div>

    <div class="mt-4" id="create-company-container">
      <.dialog_drawer_wrapper
        id="create-company-dialog"
        show={@show_dialog}
        mode={@mode}
        hook="DialogDrawerMode"
        name="Create New Company"
        description="Add a new company to your dashboard"
        on_cancel={JS.push("close_create_company_dialog")}
      >
        <div class="relative grid gap-4 border-none">
          <form
            id="create-company-form"
            phx-submit={@on_create}
            class="space-y-4"
            phx-hook="ResetForm"
          >
            <div class="flex flex-col">
              <.input
                id="name"
                name="name"
                type="text"
                label="Company Name"
                value=""
                placeholder="Enter company name"
                required
              />
            </div>

            <div class="flex flex-col">
              <.input
                label="Phone Number"
                id="phone"
                name="phone"
                type="tel"
                value=""
                placeholder="Enter phone number"
              />
            </div>

            <div class="flex flex-col">
              <.input
                label="Website"
                id="website"
                name="website"
                type="url"
                value=""
                placeholder="Enter website URL"
              />
            </div>

            <div class="flex flex-col">
              <.input
                label="Email"
                id="email"
                name="email"
                type="email"
                value=""
                placeholder="Enter company email"
              />
            </div>

            <div class="flex flex-col">
              <.input
                label="Address"
                id="address"
                name="address"
                type="text"
                value=""
                placeholder="Enter company address"
              />
            </div>

            <div class="flex flex-col">
              <.textarea
                label="Description"
                id="description"
                name="description"
                value=""
                placeholder="Enter company description"
                rows="3"
              />
            </div>

            <div class="flex flex-col gap-2 mt-4">
              <.button type="submit" class="w-full">Create Company</.button>
              <.button
                variant="outline"
                type="button"
                phx-click={JS.push("close_create_company_dialog")}
                class="w-full"
              >
                Cancel
              </.button>
            </div>
          </form>
        </div>
      </.dialog_drawer_wrapper>
    </div>
    """
  end

  defp get_company_limit(subscription) do
    case subscription do
      # For super admin or no subscription
      nil ->
        999_999

      # For super admin
      %{plan: nil} ->
        999_999

      %{plan: plan} ->
        case plan.features["projects"] do
          "Unlimited" -> 999_999
          limit when is_integer(limit) -> limit
          limit when is_binary(limit) ->
            case Integer.parse(limit) do
              {int_limit, ""} -> int_limit
              _ -> 0
            end
          _ -> 0
        end
    end
  end
end
