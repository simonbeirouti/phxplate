defmodule PhxplateWeb.CompanyLive.Index do
  @moduledoc """
  LiveView module for managing companies.

  ## Responsibilities
  - Displays list of companies
  - Handles company creation, editing, and deletion
  - Manages real-time updates for company data
  - Implements role-based access control

  ## State Management
  - Maintains socket assigns for companies list
  - Handles form state for company creation/editing
  - Manages pagination and filtering state
  """

  use PhxplateWeb, :live_view
  alias Phxplate.Companies
  alias Phxplate.Companies.Company

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream(socket, :companies, Companies.list_companies())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Company")
    |> assign(:company, Companies.get_company!(id))
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Company")
    |> assign(:company, %Company{})
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Listing Companies")
    |> assign(:company, nil)
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    company = Companies.get_company!(id)
    {:ok, _} = Companies.delete_company(company)

    {:noreply, stream_delete(socket, :companies, company)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Companies</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="flex justify-end mb-4">
            <.link
              navigate={~p"/companies/new"}
              class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              New Company
            </.link>
          </div>
          <div class="overflow-hidden bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900">Company List</h3>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">A list of all companies in the system.</p>
            </div>
            <div class="border-t border-gray-200">
              <ul role="list" class="divide-y divide-gray-200">
                <li :for={{id, company} <- @streams.companies} id={id}>
                  <div class="px-4 py-4 sm:px-6">
                    <div class="flex items-center justify-between">
                      <div class="flex-1 min-w-0">
                        <p class="text-sm font-medium text-indigo-600 truncate">
                          <%= company.name %>
                        </p>
                        <p class="mt-1 text-sm text-gray-500">
                          <%= company.description %>
                        </p>
                      </div>
                      <div class="flex items-center space-x-4">
                        <.link
                          navigate={~p"/companies/#{company}"}
                          class="text-sm font-medium text-indigo-600 hover:text-indigo-900"
                        >
                          View
                        </.link>
                        <.link
                          navigate={~p"/companies/#{company}/edit"}
                          class="text-sm font-medium text-indigo-600 hover:text-indigo-900"
                        >
                          Edit
                        </.link>
                        <button
                          type="button"
                          phx-click={JS.push("delete", value: %{id: company.id}) |> hide("##{id}")}
                          class="text-sm font-medium text-red-600 hover:text-red-900"
                        >
                          Delete
                        </button>
                      </div>
                    </div>
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
