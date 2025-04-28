defmodule PhxplateWeb.DashboardController do
  use PhxplateWeb, :controller
  alias Phxplate.Accounts.User

  def index(conn, _params) do
    render(conn, :index)
  end

  def basic(conn, _params) do
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      render(conn, :basic, data: %{
        message: "Welcome to the Basic Dashboard!",
        features: ["View basic reports", "Access limited settings"]
      })
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def admin(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      render(conn, :admin, data: %{
        message: "Welcome to the Admin Dashboard!",
        features: ["Manage users", "View analytics", "Configure system settings"],
        users: Phxplate.Accounts.list_users()
      })
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def super_admin(conn, _params) do
    if User.is_super_admin?(conn.assigns.current_user) do
      render(conn, :super_admin, data: %{
        message: "Welcome to the Super Admin Dashboard!",
        features: ["Manage all users", "Configure system-wide settings", "Access audit logs"],
        system_stats: %{
          total_users: Phxplate.Accounts.count_users(),
          active_users: Phxplate.Accounts.count_active_users(),
          system_status: "All systems operational"
        }
      })
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end
end
