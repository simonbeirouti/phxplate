defmodule PhxplateWeb.TeamLive.Show do
  use PhxplateWeb, :live_view
  alias Phxplate.Teams
  alias Phxplate.Teams.Team

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    team = Teams.get_team!(id)
    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:team, team)}
  end

  defp page_title(:show), do: "Show Team"
  defp page_title(:edit), do: "Edit Team"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-10">
      <header>
        <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <h1 class="text-3xl font-bold leading-tight tracking-tight text-gray-900">Team Details</h1>
        </div>
      </header>
      <main>
        <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
          <div class="overflow-hidden bg-white shadow sm:rounded-lg">
            <div class="px-4 py-5 sm:px-6">
              <h3 class="text-lg font-medium leading-6 text-gray-900">Team Information</h3>
              <p class="mt-1 max-w-2xl text-sm text-gray-500">Details about the team and its members.</p>
            </div>
            <div class="border-t border-gray-200 px-4 py-5 sm:px-6">
              <dl class="grid grid-cols-1 gap-x-4 gap-y-8 sm:grid-cols-2">
                <div class="sm:col-span-1">
                  <dt class="text-sm font-medium text-gray-500">Team Name</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @team.name %></dd>
                </div>
                <div class="sm:col-span-1">
                  <dt class="text-sm font-medium text-gray-500">Description</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @team.description %></dd>
                </div>
                <div class="sm:col-span-1">
                  <dt class="text-sm font-medium text-gray-500">Created At</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @team.inserted_at %></dd>
                </div>
                <div class="sm:col-span-1">
                  <dt class="text-sm font-medium text-gray-500">Last Updated</dt>
                  <dd class="mt-1 text-sm text-gray-900"><%= @team.updated_at %></dd>
                </div>
              </dl>
            </div>
            <div class="border-t border-gray-200 px-4 py-5 sm:px-6">
              <div class="flex justify-end">
                <.link
                  navigate={~p"/teams/#{@team}/edit"}
                  class="inline-flex items-center rounded-md border border-transparent bg-indigo-600 px-4 py-2 text-sm font-medium text-white shadow-sm hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                >
                  Edit Team
                </.link>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
    """
  end
end
