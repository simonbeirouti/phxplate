defmodule PhxplateWeb.Authorization do
  @moduledoc """
  Provides authorization helpers for role-based access control.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Phxplate.Accounts.User

  def init(role), do: role

  def call(conn, role) do
    if authorized?(conn.assigns.current_user, role) do
      conn
    else
      conn
      |> put_flash(:error, "You are not authorized to access this page.")
      |> redirect(to: "/dashboard")
      |> halt()
    end
  end

  def authorized?(user, role) do
    case role do
      :basic -> user.role in [:basic, :admin, :super_admin]
      :admin -> user.role in [:admin, :super_admin]
      :super_admin -> user.role == :super_admin
      _ -> false
    end
  end

  def ensure_company_owner(conn, _opts) do
    case conn.params do
      %{"id" => company_id} ->
        case Integer.parse(company_id) do
          {id, ""} ->
            company = Phxplate.Companies.get_company!(id)
            if company.owner_id == conn.assigns.current_user.id do
              conn
            else
              conn
              |> put_flash(:error, "You don't have access to this company")
              |> redirect(to: "/dashboard/admin/companies")
              |> halt()
            end
          _ ->
            conn
            |> put_flash(:error, "Invalid company ID")
            |> redirect(to: "/dashboard/admin/companies")
            |> halt()
        end
      _ -> conn
    end
  end

  def is_company_owner?(company, user) do
    company.owner_id == user.id
  end

  @doc """
  Plug to ensure the current user has the required role.
  """
  def require_role(conn, required_role) do
    case call(conn, required_role) do
      {:ok, _user} -> conn
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(PhxplateWeb.ErrorHTML)
        |> render(:"401")
        |> halt()
      {:error, :forbidden} ->
        conn
        |> put_status(:forbidden)
        |> put_view(PhxplateWeb.ErrorHTML)
        |> render(:"403")
        |> halt()
    end
  end
end
