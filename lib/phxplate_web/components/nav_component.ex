defmodule PhxplateWeb.Components.NavComponent do
  use PhxplateWeb, :html

  attr :current_user, :any
  attr :current_path, :string

  def nav(assigns) do
    public_links = [
      %{href: ~p"/about", label: "About"},
      %{href: ~p"/contact", label: "Contact"},
      %{href: ~p"/pricing", label: "Pricing"}
    ]

    show_nav = !String.starts_with?(assigns.current_path, "/dashboard")
    assigns = assign(assigns, :show_nav, show_nav)
    assigns = assign(assigns, :public_links, public_links)

    ~H"""
    <nav :if={@show_nav} class="fixed relative top-0 z-50 w-full border-b bg-white">
      <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
        <div class="flex items-center">
          <.link href={~p"/"} class="flex items-center space-x-2">
            <span class="text-xl font-bold">{Phxplate.config([:title])}</span>
          </.link>
        </div>

        <div class="flex items-center space-x-4">
          <div class="hidden md:flex md:items-center space-x-4">
            <%= for link <- @public_links do %>
              <.link href={link.href} class="text-sm font-medium hover:text-gray-900">
                {link.label}
              </.link>
            <% end %>
          </div>

          <div class="hidden md:flex md:items-center">
            <%= if @current_user do %>
              <.link
                href={~p"/dashboard"}
                class="rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
              >
                Dashboard
              </.link>
            <% else %>
              <.link href={~p"/users/register"} class="text-sm font-medium hover:text-gray-900">
                Sign up
              </.link>
              <.link
                href={~p"/users/log_in"}
                class="rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90"
              >
                Sign in
              </.link>
            <% end %>
          </div>
        </div>

        <div class="md:hidden">
          <button
            type="button"
            class="inline-flex items-center justify-center rounded-md p-2 text-gray-700 hover:bg-gray-100 hover:text-gray-900"
            phx-click={JS.toggle(to: "#mobile-menu")}
          >
            <span class="sr-only">Open main menu</span>
            <.icon name="hero-bars-3" class="h-6 w-6" />
          </button>
        </div>
      </div>

      <div id="mobile-menu" class="hidden md:hidden">
        <div class="space-y-1 px-2 pb-3 pt-2">
          <%= for link <- @public_links do %>
            <.link
              href={link.href}
              class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50"
            >
              {link.label}
            </.link>
          <% end %>
          <%= if @current_user do %>
            <.link
              href={~p"/dashboard"}
              class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50"
            >
              Dashboard
            </.link>
          <% else %>
            <.link
              href={~p"/users/register"}
              class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50"
            >
              Sign up
            </.link>
            <.link
              href={~p"/users/log_in"}
              class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50"
            >
              Sign in
            </.link>
          <% end %>
        </div>
      </div>
    </nav>
    """
  end
end
