defmodule PhxplateWeb.TeamsLive do
  @moduledoc """
  LiveView component for managing teams (formerly companies).
  Uses the dashboard subscription system for real-time updates.
  """

  use PhxplateWeb, :live_view
  alias Phxplate.Companies
  alias PhxplateWeb.DashboardSubscription

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      DashboardSubscription.subscribe("teams")
    end

    teams = Companies.list_companies()
    DashboardSubscription.update_state("teams", teams)

    {:ok, stream(socket, :teams, teams)}
  end

  @impl true
  def handle_info({:state_updated, teams}, socket) do
    {:noreply, stream(socket, :teams, teams, reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <.header>
        Teams
        <:actions>
          <.link :if={authorized?(:create, @current_user)} patch={~p"/teams/new"} phx-click={JS.push_focus()}>
            <.button>New Team</.button>
          </.link>
        </:actions>
      </.header>

      <.table
        id="teams"
        rows={@streams.teams}
        row_click={fn {_id, team} -> JS.navigate(~p"/teams/#{team}") end}
      >
        <:col :let={{_id, team}} label="Name"><%= team.name %></:col>
        <:col :let={{_id, team}} label="Email"><%= team.email %></:col>
        <:col :let={{_id, team}} label="Phone"><%= team.phone %></:col>
        <:action :let={{_id, team}}>
          <div class="sr-only">
            <.link navigate={~p"/teams/#{team}"}>Show</.link>
          </div>
          <.link :if={authorized?(:edit, @current_user)} patch={~p"/teams/#{team}/edit"}>Edit</.link>
        </:action>
        <:action :let={{id, team}}>
          <.link
            :if={authorized?(:delete, @current_user)}
            phx-click={JS.push("delete", value: %{id: team.id}) |> hide("##{id}")}
            data-confirm="Are you sure?"
          >
            Delete
          </.link>
        </:action>
      </.table>
    </div>
    """
  end

  defp authorized?(action, user) do
    case action do
      :view -> user.role in [:basic, :admin, :super_admin]
      :create -> user.role in [:admin, :super_admin]
      :edit -> user.role == :super_admin
      :delete -> user.role == :super_admin
      _ -> false
    end
  end
end
