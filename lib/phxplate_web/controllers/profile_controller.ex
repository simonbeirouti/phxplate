defmodule PhxplateWeb.ProfileController do
  use PhxplateWeb, :controller
  alias Phxplate.Profiles

  def public_index(conn, _params) do
    profiles = Profiles.list_profiles()
    render(conn, :public_index, profiles: profiles)
  end

  def public_show(conn, %{"id" => id}) do
    case Profiles.get_profile(id) do
      nil ->
        conn
        |> put_flash(:error, "Profile not found")
        |> redirect(to: ~p"/profiles")
      profile ->
        render(conn, :public_show, profile: profile)
    end
  end
end
