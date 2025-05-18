defmodule PhxplateWeb.AdminController do
  @moduledoc """
  Controller for admin-only functionality.

  This controller handles admin-specific actions and ensures that only users
  with admin privileges can access these functionalities. It includes
  role-based authorization checks.
  """
  use PhxplateWeb, :controller
  alias Phxplate.Accounts.User

  @doc """
  Renders the admin index page if the user has admin privileges.

  Checks if the current user has admin role and renders admin content,
  or returns a 403 Forbidden response if the user lacks admin privileges.
  """
  def index(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) do
      # Admin-only content
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end
end
