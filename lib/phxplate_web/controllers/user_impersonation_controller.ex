defmodule PhxplateWeb.UserImpersonationController do
  use PhxplateWeb, :controller

  def impersonate(conn, %{"id" => user_id}) do
    current_user = conn.assigns.current_user

    cond do
      # Only super admins can impersonate
      !current_user || current_user.role != :super_admin ->
        conn
        |> put_status(:forbidden)
        |> put_view(PhxplateWeb.ErrorHTML)
        |> render(:"403")

      # Can't impersonate yourself
      user_id == current_user.id ->
        conn
        |> put_flash(:error, "You cannot impersonate yourself")
        |> redirect(to: ~p"/dashboard/super_admin/users")

      true ->
        # Start impersonation
        conn
        |> put_session(:impersonated_user_id, user_id)
        |> put_flash(:info, "Now impersonating user")
        |> redirect(to: ~p"/dashboard")
    end
  end

  def stop_impersonating(conn, _params) do
    conn
    |> delete_session(:impersonated_user_id)
    |> put_flash(:info, "Stopped impersonating user")
    |> redirect(to: ~p"/dashboard/super_admin/users")
  end
end
