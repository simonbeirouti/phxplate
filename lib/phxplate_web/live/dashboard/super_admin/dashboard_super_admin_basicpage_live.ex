defmodule PhxplateWeb.Dashboard.SuperAdmin.UsersLive do
  use PhxplateWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: "Super admin basicpage",
       page_description: "Just the basic super admin page within the super admin dashboard",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com"
     )}
  end

  def render(assigns) do
    ~H"""
    <main>
      <h1>This is a super admin page 1 only for super admin roles</h1>
    </main>
    """
  end
end
