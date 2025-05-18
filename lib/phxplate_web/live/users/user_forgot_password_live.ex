defmodule PhxplateWeb.UserForgotPasswordLive do
  use PhxplateWeb, :live_view

  alias Phxplate.Accounts
  alias PhxplateWeb.PageMeta

  def render(assigns) do
    ~H"""
    <div class="flex items-center justify-center h-full">
      <div class="w-full max-w-sm mt-64 lg:mt-0">
        <.header class="text-center">
          Forgot your password?
          <:subtitle>We'll send a password reset link to your inbox</:subtitle>
        </.header>

        <.simple_form for={@form} id="reset_password_form" phx-submit="send_email">
          <.input field={@form[:email]} type="email" placeholder="Email" required />
          <:actions>
            <.button phx-disable-with="Sending..." class="w-full">
              Send password reset instructions
            </.button>
          </:actions>
        </.simple_form>
        <div class="flex flex-col items-center justify-center gap-4 mt-4">
          <div class="w-full h-px bg-primary/50" />
          <.link class="w-full" href={~p"/register"}>
            <.button variant="outline" class="w-full">Register</.button>
          </.link>
          <.link class="w-full" href={~p"/login"}>
            <.button variant="outline" class="w-full">Log in</.button>
          </.link>
        </div>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    socket =
      socket
      |> PageMeta.assign_metadata(
        title: "Reset Password",
        description: "Request a password reset link",
        url: "/reset-password"
      )
      |> assign(form: to_form(%{}, as: "user"))

    {:ok, socket}
  end

  def handle_event("send_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/reset-password/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions to reset your password shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> redirect(to: ~p"/")}
  end
end
