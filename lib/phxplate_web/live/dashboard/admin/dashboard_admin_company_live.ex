defmodule PhxplateWeb.Dashboard.Admin.CompanyLive do
  @moduledoc """
  LiveView for company management within the admin dashboard.

  This view displays a grid of companies owned by the current user and
  provides functionality to create new companies. It subscribes to
  real-time updates for companies via PubSub.
  """
  use PhxplateWeb, :live_view

  alias Phxplate.{Companies, Subscriptions, Repo}
  alias Phxplate.PubSub.DataSync
  alias PhxplateWeb.PageMeta
  import PhxplateWeb.Components.CompaniesGrid
  import PhxplateWeb.Dashboard.Admin.CompanyHelpers

  @doc """
  Initializes the LiveView with companies data and subscriptions.

  Loads companies owned by the current user, sets up PubSub subscriptions
  for real-time updates, and determines the company creation limit based
  on the user's subscription plan.
  """
  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_user

    if connected?(socket) do
      DataSync.subscribe("companies", current_user.id)
      DataSync.subscribe("companies", "all")
    end

    companies = Companies.list_companies_by_owner(current_user.id)
    subscription = if current_user.role == :super_admin do
      %{plan: %{features: %{"projects" => "Unlimited"}}}
    else
      Subscriptions.get_user_subscription(current_user.id)
    end

    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "Company Management",
       description: "Manage your companies",
       url: "/dashboard/admin/companies"
     )
     |> assign(
       companies: companies,
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
    if company.owner_id == socket.assigns.current_user.id and not Enum.any?(socket.assigns.companies, &(&1.id == company.id)) do
      company = Repo.preload(company, [employees: [:profile]])
      {:noreply, update(socket, :companies, fn companies -> [company | companies] end)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:updated, %{type: :company, company: company}}, socket) do
    if company.owner_id == socket.assigns.current_user.id do
      company = Repo.preload(company, [employees: [:profile]])
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
        Companies
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
