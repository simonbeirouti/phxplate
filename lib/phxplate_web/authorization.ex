defmodule PhxplateWeb.Authorization do
  @moduledoc """
  Provides authorization helpers for role-based access control.
  """

  import Phoenix.Controller
  import Plug.Conn

  alias Phxplate.Accounts.User

  def init(opts), do: opts

  def call(conn, opts) do
    case fetch_current_user(conn) do
      {:ok, user} ->
        case authorize(user, opts) do
          {:ok, _} -> conn
          {:error, :forbidden} ->
            conn
            |> put_status(:forbidden)
            |> put_view(PhxplateWeb.ErrorHTML)
            |> render(:"403")
            |> halt()
        end
      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> put_view(PhxplateWeb.ErrorHTML)
        |> render(:"401")
        |> halt()
    end
  end

  defp fetch_current_user(conn) do
    case conn.assigns[:current_user] do
      %User{} = user -> {:ok, user}
      _ -> {:error, :unauthorized}
    end
  end

  defp authorize(user, required_role) do
    case required_role do
      :basic -> if User.is_basic?(user) or User.is_admin?(user) or User.is_super_admin?(user), do: {:ok, user}, else: {:error, :forbidden}
      :admin -> if User.is_admin?(user) or User.is_super_admin?(user), do: {:ok, user}, else: {:error, :forbidden}
      :super_admin -> if User.is_super_admin?(user), do: {:ok, user}, else: {:error, :forbidden}
      _ -> {:error, :forbidden}
    end
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
