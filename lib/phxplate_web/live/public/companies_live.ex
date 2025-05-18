defmodule PhxplateWeb.Public.CompaniesLive do
  use PhxplateWeb, :live_view
  use SaladUI

  alias Phxplate.Companies
  alias Phxplate.PubSub.DataSync
  alias PhxplateWeb.PageMeta

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      DataSync.subscribe("companies", "all")
    end

    companies = Companies.list_companies()

    {:ok,
     socket
     |> PageMeta.assign_metadata(
       title: "Companies",
       description: "Discover amazing companies",
       url: "/companies"
     )
     |> assign(companies: companies)
    }
  end

  @impl true
  def handle_info({:created, %{type: :company, company: company}}, socket) do
    {:noreply, update(socket, :companies, fn companies -> [company | companies] end)}
  end

  def handle_info({:updated, %{type: :company, company: company}}, socket) do
    {:noreply,
     update(socket, :companies, fn companies ->
       Enum.map(companies, fn c -> if c.id == company.id, do: company, else: c end)
     end)}
  end

  def handle_info({:deleted, %{type: :company, id: company_id}}, socket) do
    {:noreply,
     update(socket, :companies, fn companies ->
       Enum.reject(companies, &(&1.id == company_id))
     end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-12">
      <div class="text-center mb-12">
        <h1 class="text-4xl font-bold text-gray-900">Companies</h1>
        <p class="mt-4 text-lg text-gray-500">Discover amazing companies</p>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= for company <- @companies do %>
          <.link navigate={~p"/companies/#{company.id}"} class="block">
            <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow duration-200">
              <div class="h-48 bg-gray-200 flex items-center justify-center">
                <%= if company.logo do %>
                  <img src={company.logo} alt={company.name} class="h-full w-full object-cover" />
                <% else %>
                  <div class="text-4xl font-bold text-gray-400">
                    <%= String.first(company.name) %>
                  </div>
                <% end %>
              </div>
              <div class="p-6">
                <h3 class="text-xl font-semibold text-gray-900"><%= company.name %></h3>
                <%= if company.description do %>
                  <p class="mt-2 text-gray-600 line-clamp-2"><%= company.description %></p>
                <% end %>
              </div>
            </div>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end
end
