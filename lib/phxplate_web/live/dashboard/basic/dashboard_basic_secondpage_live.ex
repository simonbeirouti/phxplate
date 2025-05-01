defmodule PhxplateWeb.Dashboard.Basic.SecondPageLive do
  use PhxplateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Second basic page",
       page_description: "Just the second basic page within the basic dashboard",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com"
     )}
  end

  def render(assigns) do
    ~H"""
    <main>
      <h1>This is a basic page 2 only for basic roles</h1>
    </main>
    """
  end
end
