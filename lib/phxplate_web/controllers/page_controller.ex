defmodule PhxplateWeb.PageController do
  use PhxplateWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home,
      layout: false,
      page_title: "Home",
      page_description: "Home"
    )
  end

  def about(conn, _params) do
    render(conn, :about,
      layout: false,
      page_title: "About",
      page_description: "About"
    )
  end

  def contact(conn, _params) do
    render(conn, :contact,
      layout: false,
      page_title: "Contact",
      page_description: "Contact"
    )
  end
end
