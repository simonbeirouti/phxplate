defmodule PhxplateWeb.Onboarding.ProfileLive do
  use PhxplateWeb, :live_view

  alias Phxplate.Accounts
  alias Phxplate.Accounts.Profile

  def render(assigns) do
    ~H"""
    <div class="max-w-2xl mx-auto py-16 px-4">
      <div class="mb-8 flex justify-center">
        <div class="h-12 w-12 rounded-full bg-primary-100 flex items-center justify-center">
          <.icon name="hero-user" class="h-6 w-6 text-primary-600" />
        </div>
      </div>
      <.header class="text-center">
        Complete Your Profile
        <:subtitle>
          Let's set up your profile information to get started
        </:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="profile_form"
        phx-submit="save"
        phx-change="validate"
      >
        <.error :if={@check_errors}>
          Oops, something went wrong! Please check the errors below.
        </.error>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <.input field={@form[:first_name]} type="text" label="First Name" required />
          <.input field={@form[:last_name]} type="text" label="Last Name" required />
        </div>

        <.input field={@form[:job_title]} type="text" label="Job Title" />
        <.input field={@form[:bio]} type="textarea" label="Bio" />
        <.input field={@form[:location]} type="text" label="Location" />

        <:actions>
          <.button phx-disable-with="Saving..." class="w-full">Save Profile</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    # Check if user already has a profile
    profile = case Accounts.get_profile_by_user_id(user.id) do
      nil -> %Profile{user_id: user.id}
      existing -> existing
    end

    changeset = Accounts.change_profile(profile)

    socket =
      socket
      |> assign(:check_errors, false)
      |> assign_form(changeset)

    {:ok, socket}
  end

  def handle_event("validate", %{"profile" => profile_params}, socket) do
    changeset =
      socket.assigns.current_user.id
      |> Accounts.get_profile_by_user_id()
      |> case do
        nil -> %Profile{user_id: socket.assigns.current_user.id}
        profile -> profile
      end
      |> Accounts.change_profile(profile_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("save", %{"profile" => profile_params}, socket) do
    user = socket.assigns.current_user

    # Check if user already has a profile
    save_profile(user, profile_params, socket)
  end

  defp save_profile(user, profile_params, socket) do
    case Accounts.get_profile_by_user_id(user.id) do
      nil ->
        # Create new profile
        case Accounts.create_profile(user, profile_params) do
          {:ok, _profile} ->
            {:noreply, push_navigate(socket, to: ~p"/onboarding/complete")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, check_errors: true) |> assign_form(changeset)}
        end

      profile ->
        # Update existing profile
        case Accounts.update_profile(profile, profile_params) do
          {:ok, _profile} ->
            {:noreply, push_navigate(socket, to: ~p"/onboarding/complete")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, check_errors: true) |> assign_form(changeset)}
        end
    end
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "profile")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end
end
