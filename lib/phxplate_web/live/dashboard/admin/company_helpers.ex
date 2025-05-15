defmodule PhxplateWeb.Dashboard.Admin.CompanyHelpers do
  @moduledoc """
  Helper functions for company management across live views.
  """
  alias Phxplate.{Companies, Repo}
  import Phoenix.Component
  import Phoenix.LiveView

  def handle_create_company(socket, params) do
    current_user = Repo.preload(socket.assigns.current_user, :profile)

    company_params = %{
      name: params["name"],
      phone: params["phone"],
      website: params["website"],
      email: params["email"],
      address: params["address"],
      description: params["description"],
      owner_id: current_user.id,
      plan: socket.assigns.subscription.plan.name
    }

    case Companies.create_company(company_params) do
      {:ok, company} ->
        {:noreply,
         socket
         |> update(:companies, fn companies -> [company | companies] end)
         |> put_flash(:info, "Company created successfully!")
         |> push_event("hide-modal", %{id: "create-company-dialog"})}

      {:error, changeset} ->
        error_message = case changeset.errors do
          [{field, {msg, _}} | _] -> "#{Phoenix.Naming.humanize(field)} #{msg}"
          _ -> "Failed to create company. Please try again."
        end

        {:noreply,
         socket
         |> put_flash(:error, error_message)}
    end
  end

  def handle_open_create_company_dialog(socket) do
    {:noreply, socket}
  end
end
