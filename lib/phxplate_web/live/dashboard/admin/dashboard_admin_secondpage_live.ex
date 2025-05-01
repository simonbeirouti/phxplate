defmodule PhxplateWeb.Dashboard.Admin.SecondPageLive do
  use PhxplateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Second admin page",
       page_description: "Just the second admin page within the admin dashboard",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com"
     )}
  end

  def render(assigns) do
    ~H"""
    <main>
      <h1>This is a admin page 2 only for admin roles</h1>
    </main>
    """
  end
end
