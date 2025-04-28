defmodule PhxplateWeb.AdminController do
  use PhxplateWeb, :controller
  alias Phxplate.Accounts.User

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
