defmodule PhxplateWeb.Public.CompaniesLive do
  use PhxplateWeb, :live_view
  use SaladUI

  alias Phxplate.Companies

  @impl true
  def mount(_params, _session, socket) do
    companies = Companies.list_companies()
    {:ok, assign(socket, companies: companies)}
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
