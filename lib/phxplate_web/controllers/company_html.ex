defmodule PhxplateWeb.CompanyHTML do
  use PhxplateWeb, :html

  embed_templates "company_html/*"

  def public_index(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <h1 class="text-3xl font-bold text-gray-900 mb-8">Companies</h1>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= for company <- @companies do %>
          <.link href={~p"/companies/#{company.id}"} class="block">
            <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow duration-200">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium text-gray-900"><%= company.name %></h3>
                <p class="mt-1 text-sm text-gray-500"><%= company.description %></p>
                <div class="mt-4">
                  <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600">
                    <%= company.industry %>
                  </span>
                </div>
              </div>
            </div>
          </.link>
        <% end %>
      </div>
    </div>
    """
  end

  def public_show(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6">
          <h1 class="text-3xl font-bold text-gray-900"><%= @company.name %></h1>
          <p class="mt-1 max-w-2xl text-sm text-gray-500"><%= @company.description %></p>
        </div>
        <div class="border-t border-gray-200">
          <dl>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Industry</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @company.industry %></dd>
            </div>
            <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Location</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @company.location %></dd>
            </div>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Website</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <.link href={@company.website} class="text-primary hover:text-primary/80" target="_blank">
                  <%= @company.website %>
                </.link>
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
    """
  end
end
