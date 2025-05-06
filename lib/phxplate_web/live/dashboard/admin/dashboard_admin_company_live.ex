defmodule PhxplateWeb.Dashboard.Admin.CompanyLive do
  use PhxplateWeb, :live_view

  alias Phxplate.{Companies, Subscriptions}
  import PhxplateWeb.Components.CompaniesGrid

  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user
    companies = Companies.list_companies_by_owner(current_user.id)
    subscription = Subscriptions.get_user_subscription(current_user.id)

    {:ok,
     assign(socket,
       page_title: "Company Management",
       page_description: "Manage your companies",
       companies: companies,
       subscription: subscription
     )}
  end

  def handle_event("create_company", _params, socket) do
    {:noreply, put_flash(socket, :info, "Company creation feature coming soon!")}
  end

  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <h2 class="text-2xl font-semibold text-gray-900">Companies</h2>
        <:subtitle>
          View all companies that are owned by you
        </:subtitle>
      </.header>
      <.companies_grid
        companies={@companies}
        subscription={@subscription}
        on_create="create_company"
      />
    </div>
    """
  end
end
