defmodule PhxplateWeb.PageController do
  use PhxplateWeb, :controller
  alias PhxplateWeb.PageMeta

  def home(conn, _params) do
    conn
    |> PageMeta.assign_metadata(
      title: "Home",
      description: "Welcome to Phxplate"
    )
    |> render(:home, layout: false)
  end

  def about(conn, _params) do
    conn
    |> PageMeta.assign_metadata(
      title: "About",
      description: "Learn more about Phxplate"
    )
    |> render(:about, layout: false)
  end

  def contact(conn, _params) do
    conn
    |> PageMeta.assign_metadata(
      title: "Contact",
      description: "Get in touch with us"
    )
    |> render(:contact, layout: false)
  end
end
