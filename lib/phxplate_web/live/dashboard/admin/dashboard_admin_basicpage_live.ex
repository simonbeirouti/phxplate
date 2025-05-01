defmodule PhxplateWeb.Dashboard.Admin.BasicPageLive do
  use PhxplateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Admin page",
       page_description: "Just a basic admin page within the basic dashboard",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com"
     )}
  end

  def render(assigns) do
    ~H"""
    <main>
      <h1>This is a admin page 1 only for admin roles</h1>
    </main>
    """
  end
end
