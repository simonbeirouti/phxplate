defmodule PhxplateWeb.PageController do
  use PhxplateWeb, :controller
  alias PhxplateWeb.PageMeta

  def home(conn, _params) do
    conn
    |> PageMeta.assign_metadata(
      title: "Home",
      description: "Welcome to Phxplate",
      url: "/"
    )
    |> render(:home, layout: false)
  end

  def about(conn, _params) do
    conn
    |> PageMeta.assign_metadata(
      title: "About",
      description: "Learn more about Phxplate",
      url: "/about"
    )
    |> render(:about, layout: false)
  end
end
