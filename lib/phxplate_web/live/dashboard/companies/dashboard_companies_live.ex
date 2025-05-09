defmodule PhxplateWeb.Dashboard.Companies.CompaniesLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Companies

  def mount(%{"id" => id}, _session, socket) do
    case Companies.get_company!(id) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Company not found")
         |> redirect(to: ~p"/dashboard/companies")}

      company ->
        {:ok,
         assign(socket,
           page_title: company.name,
           page_description: "Company details",
           page_image: "https://via.placeholder.com/1200x630",
           page_url: "https://phxplate.com",
           company: company
         )}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Companies",
       page_description: "Companies list",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com",
       companies: Companies.list_companies()
     )}
  end

  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Companies")
  end

  defp apply_action(socket, :show, %{"id" => _id}) do
    socket
    |> assign(:page_title, "Company Details")
  end

  def render(%{live_action: :show} = assigns) do
    ~H"""
    <.header class="text-center">
      {@company.name}
      <:subtitle>Company Details</:subtitle>
      <:actions>
        <.link
          href="/dashboard/admin/company"
          class="text-sm font-semibold leading-6 text-zinc-900 hover:text-zinc-700"
        >
          Back to companies
        </.link>
      </:actions>
    </.header>

    <div class="mt-6 border-t border-gray-100">
      <dl class="divide-y divide-gray-100">
        <div class="px-4 py-6 sm:grid sm:grid-cols-3 sm:gap-4 sm:px-0">
          <dt class="text-sm font-medium leading-6 text-gray-900">Name</dt>
          <dd class="mt-1 text-sm leading-6 text-gray-700 sm:col-span-2 sm:mt-0">{@company.name}</dd>
        </div>
        <!-- Add more company details as needed -->
      </dl>
    </div>
    """
  end

  def render(%{live_action: :index} = assigns) do
    ~H"""
    <.header class="text-center">
      Companies
      <:subtitle>Manage your companies</:subtitle>
    </.header>

    <div class="mt-6">
      <%= if @companies == [] do %>
        <.empty_state>
          No companies found
        </.empty_state>
      <% else %>
        <div class="overflow-hidden rounded-xl border border-zinc-200">
          <table class="min-w-full divide-y divide-gray-300">
            <thead class="bg-zinc-50">
              <tr>
                <th
                  scope="col"
                  class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-zinc-900 sm:pl-6"
                >
                  Name
                </th>
                <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
                  <span class="sr-only">View</span>
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200 bg-white">
              <%= for company <- @companies do %>
                <tr>
                  <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-zinc-900 sm:pl-6">
                    {company.name}
                  </td>
                  <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
                    <.link
                      patch={~p"/dashboard/admin/companies/#{company.id}"}
                      class="text-indigo-600 hover:text-indigo-900"
                    >
                      View<span class="sr-only">, <%= company.name %></span>
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="text-center border border-zinc-200 rounded-xl p-6">
      No companies found
    </div>
    """
  end
end
