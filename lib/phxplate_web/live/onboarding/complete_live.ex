defmodule PhxplateWeb.Onboarding.CompleteLive do
  use PhxplateWeb, :live_view

  alias Phxplate.Accounts

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-16 px-4 text-center">
      <div class="mb-8">
        <div class="mx-auto flex items-center justify-center h-16 w-16 rounded-full bg-green-100">
          <.icon name="hero-check" class="h-8 w-8 text-green-600" />
        </div>
      </div>

      <.header>
        Onboarding Complete!
        <:subtitle>
          Thank you for setting up your profile. You're all set to start using the platform.
        </:subtitle>
      </.header>

      <div class="mt-8">
        <.button phx-click="go_to_dashboard" class="w-full md:w-auto">
          Go to Dashboard
        </.button>
      </div>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  def handle_event("go_to_dashboard", _params, socket) do
    user = socket.assigns.current_user

    # Mark onboarding as completed
    {:ok, _updated_user} = Accounts.complete_onboarding(user)

    {:noreply, push_navigate(socket, to: ~p"/dashboard")}
  end
end
