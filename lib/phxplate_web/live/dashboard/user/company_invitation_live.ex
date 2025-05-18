defmodule PhxplateWeb.CompanyInvitationLive do
  @moduledoc """
  LiveView for handling company invitations.

  This view is responsible for displaying a company invitation to a user
  and providing functionality to accept the invitation. It validates the
  invitation token and shows appropriate success or error messages.
  """
  use PhxplateWeb, :live_view

  alias Phxplate.Companies

  @doc """
  Initializes the LiveView with invitation data.

  Validates the invitation token, retrieves the company information,
  and assigns both to the socket. Redirects with an error message
  if the invitation is invalid or expired.
  """
  def mount(%{"token" => token}, _session, socket) do
    case Companies.get_invitation_by_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Invalid or expired invitation.")
         |> redirect(to: ~p"/")}

      invitation ->
        company = Companies.get_company!(invitation.company_id)
        {:ok, assign(socket, invitation: invitation, company: company)}
    end
  end

  def handle_event("accept_invitation", _params, socket) do
    %{invitation: invitation, current_user: current_user} = socket.assigns

    case Companies.accept_invitation(invitation, current_user) do
      {:ok, _employee} ->
        {:noreply,
         socket
         |> put_flash(:info, "You have successfully joined #{socket.assigns.company.name}.")
         |> redirect(to: ~p"/dashboard")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error accepting invitation.")
         |> redirect(to: ~p"/")}
    end
  end

  @doc """
  Renders the invitation acceptance view.

  Displays a card with the company name and an accept button.
  """
  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-8 px-4">
      <div class="bg-white shadow sm:rounded-lg">
        <div class="px-4 py-5 sm:p-6">
          <h3 class="text-lg leading-6 font-medium text-gray-900">
            Company Invitation
          </h3>
          <div class="mt-2 max-w-xl text-sm text-gray-500">
            <p>
              You have been invited to join <%= @company.name %>
            </p>
          </div>
          <div class="mt-5">
            <button
              phx-click="accept_invitation"
              class="inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md shadow-sm text-white bg-primary-600 hover:bg-primary-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-primary-500"
            >
              Accept Invitation
            </button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
