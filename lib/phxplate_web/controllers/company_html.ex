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
                    <%= company.plan %>
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
              <dt class="text-sm font-medium text-gray-500">Plan</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @company.plan %></dd>
            </div>
            <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Address</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @company.address %></dd>
            </div>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Contact</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <div><%= @company.email %></div>
                <div><%= @company.phone %></div>
              </dd>
            </div>
          </dl>
        </div>
      </div>
    </div>
    """
  end

  def dashboard_index(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Companies</h1>
        <.link
          href={~p"/dashboard/companies/new"}
          class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
        >
          New Company
        </.link>
      </div>

      <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3">
        <%= for company <- @companies do %>
          <.link href={~p"/dashboard/companies/#{company.id}"} class="block">
            <div class="bg-white overflow-hidden shadow rounded-lg hover:shadow-lg transition-shadow duration-200">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium text-gray-900"><%= company.name %></h3>
                <p class="mt-1 text-sm text-gray-500"><%= company.description %></p>
                <div class="mt-4 flex items-center justify-between">
                  <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600">
                    <%= company.plan %>
                  </span>
                  <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                    Active
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

  def dashboard_show(assigns) do
    ~H"""
    <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8 py-8">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900"><%= @company.name %></h1>
        <div class="flex space-x-4">
          <.link
            href={~p"/dashboard/companies/#{@company.id}/edit"}
            class="inline-flex items-center rounded-md border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-700 shadow-sm hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
          >
            Edit
          </.link>
          <.link
            href={~p"/dashboard/companies"}
            class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
          >
            Back to Companies
          </.link>
        </div>
      </div>

      <div class="bg-white shadow overflow-hidden sm:rounded-lg">
        <div class="px-4 py-5 sm:px-6">
          <h2 class="text-lg font-medium text-gray-900">Company Information</h2>
          <p class="mt-1 max-w-2xl text-sm text-gray-500"><%= @company.description %></p>
        </div>
        <div class="border-t border-gray-200">
          <dl>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Plan</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @company.plan %></dd>
            </div>
            <div class="bg-white px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Address</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2"><%= @company.address %></dd>
            </div>
            <div class="bg-gray-50 px-4 py-5 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-6">
              <dt class="text-sm font-medium text-gray-500">Contact</dt>
              <dd class="mt-1 text-sm text-gray-900 sm:mt-0 sm:col-span-2">
                <div><%= @company.email %></div>
                <div><%= @company.phone %></div>
              </dd>
            </div>
          </dl>
        </div>
      </div>

      <div class="mt-8">
        <h2 class="text-lg font-medium text-gray-900 mb-4">Employees</h2>
        <div class="bg-white shadow overflow-hidden sm:rounded-lg">
          <ul role="list" class="divide-y divide-gray-200">
            <%= for employee <- @employees do %>
              <li class="px-4 py-4 sm:px-6">
                <div class="flex items-center justify-between">
                  <div class="flex items-center">
                    <div class="ml-3">
                      <p class="text-sm font-medium text-gray-900"><%= employee.first_name %> <%= employee.last_name %></p>
                      <p class="text-sm text-gray-500"><%= employee.position %></p>
                    </div>
                  </div>
                  <div class="ml-4 flex-shrink-0">
                    <span class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800">
                      Active
                    </span>
                  </div>
                </div>
              </li>
            <% end %>
          </ul>
        </div>
      </div>
    </div>
    """
  end
end
