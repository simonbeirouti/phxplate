defmodule PhxplateWeb.UserImpersonationController do
  @moduledoc """
  Controller for user impersonation functionality.

  Allows super admin users to temporarily assume the identity of another user
  for debugging and support purposes. This controller provides actions
  to start and stop impersonation sessions.
  """
  use PhxplateWeb, :controller

  @doc """
  Starts an impersonation session for a super admin user.

  Only super admin users can impersonate other users. The impersonated user's
  ID is stored in the session so that the application can distinguish between
  the real user and the impersonated user.

  ## Parameters

  * `id` - The ID of the user to impersonate
  """
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

  @doc """
  Ends an active impersonation session.

  Removes the impersonated user ID from the session and redirects
  the admin back to the users list.
  """
  def stop_impersonating(conn, _params) do
    conn
    |> delete_session(:impersonated_user_id)
    |> put_flash(:info, "Stopped impersonating user")
    |> redirect(to: ~p"/dashboard/super_admin/users")
  end
end
