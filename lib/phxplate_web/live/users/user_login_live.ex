defmodule PhxplateWeb.UserLoginLive do
  @moduledoc """
  LiveView for user authentication login.

  This view provides a login form for users to authenticate with email and password.
  It includes a "remember me" option and links to registration and password reset.
  The form submission is processed by the standard Phoenix controller action,
  not within the LiveView.
  """
  use PhxplateWeb, :live_view
  alias PhxplateWeb.PageMeta

  @doc """
  Renders the login form.

  Displays a form with email and password fields, "remember me" checkbox,
  and links to registration and password reset pages.
  """
  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full">
      <div class="w-full max-w-sm mt-64 lg:mt-0">
        <.header class="text-center">
          Log in to account
          <:subtitle>
            Don't have an account?
            <.link navigate={~p"/register"} class="font-semibold text-brand hover:underline">
              Sign up
            </.link>
            for an account now.
          </:subtitle>
        </.header>

        <.simple_form for={@form} id="login_form" action={~p"/login"} phx-update="ignore">
          <.input field={@form[:email]} type="email" label="Email" required />
          <.input field={@form[:password]} type="password" label="Password" required />

          <:actions>
            <.input field={@form[:remember_me]} type="checkbox" label="Keep me logged in" />
            <.link href={~p"/reset-password"} class="text-sm font-semibold">
              Forgot your password?
            </.link>
          </:actions>
          <:actions>
            <.button phx-disable-with="Logging in..." class="w-full">
              Log in <span aria-hidden="true">→</span>
            </.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  @doc """
  Initializes the LiveView with a form pre-filled with flash data.

  Sets up the initial form state, potentially pre-filling the email field
  from flash data, and configures page metadata with appropriate title
  and description.
  """
  def mount(_params, _session, socket) do
    email = Phoenix.Flash.get(socket.assigns.flash, :email)
    form = to_form(%{"email" => email}, as: "user")

    socket =
      socket
      |> PageMeta.assign_metadata(
        title: "Log in",
        description: "Log in to your account",
        url: "/login"
      )
      |> assign(form: form)

    {:ok, socket, temporary_assigns: [form: form]}
  end
end
