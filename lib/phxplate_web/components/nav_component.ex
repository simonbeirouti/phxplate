defmodule PhxplateWeb.Components.NavComponent do
  use PhxplateWeb, :html

  attr :current_user, :any
  attr :current_path, :string

  def nav(assigns) do
    # Only show nav if not on dashboard route
    show_nav = !String.starts_with?(assigns.current_path, "/dashboard")
    assigns = assign(assigns, :show_nav, show_nav)

    ~H"""
    <nav :if={@show_nav} class="fixed relative top-0 z-50 w-full border-b bg-white">
      <div class="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
        <div class="flex items-center">
          <.link href={~p"/"} class="flex items-center space-x-2">
            <span class="text-xl font-bold">Phxplate</span>
          </.link>
        </div>

        <!-- Desktop Navigation -->
        <div class="hidden md:flex md:items-center md:space-x-8">
          <.link href={~p"/"} class="text-sm font-medium hover:text-gray-900">Home</.link>
          <.link href={~p"/features"} class="text-sm font-medium hover:text-gray-900">Features</.link>
          <.link href={~p"/pricing"} class="text-sm font-medium hover:text-gray-900">Pricing</.link>
          <.link href={~p"/about"} class="text-sm font-medium hover:text-gray-900">About</.link>
        </div>

        <div class="hidden md:flex md:items-center md:space-x-4">
          <%= if @current_user do %>
            <.link href={~p"/dashboard"} class="rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90">
              Dashboard
            </.link>
          <% else %>
            <.link href={~p"/users/register"} class="text-sm font-medium hover:text-gray-900">Sign up</.link>
            <.link href={~p"/users/log_in"} class="rounded-md bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary/90">
              Sign in
            </.link>
          <% end %>
        </div>

        <!-- Mobile menu button -->
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

      <!-- Mobile menu -->
      <div id="mobile-menu" class="hidden md:hidden">
        <div class="space-y-1 px-2 pb-3 pt-2">
          <.link href={~p"/"} class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50">Home</.link>
          <.link href={~p"/features"} class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50">Features</.link>
          <.link href={~p"/pricing"} class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50">Pricing</.link>
          <.link href={~p"/about"} class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50">About</.link>
          <%= if @current_user do %>
            <.link href={~p"/dashboard"} class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50">Dashboard</.link>
          <% else %>
            <.link href={~p"/users/register"} class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50">Sign up</.link>
            <.link href={~p"/users/log_in"} class="block rounded-md px-3 py-2 text-base font-medium hover:bg-gray-50">Sign in</.link>
          <% end %>
        </div>
      </div>
    </nav>
    """
  end
end
