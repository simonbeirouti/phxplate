defmodule PhxplateWeb.Dashboard.Account.SettingsLive do
  use PhxplateWeb, :live_component
  alias Phxplate.Accounts

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:email_form, to_form(%{}, as: :user))
      |> assign(:email_form_current_password, nil)
      |> assign(:password_form, to_form(%{}, as: :user))
      |> assign(:loading_email, false)
      |> assign(:loading_password, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    email_form = to_form(user_params, as: :user)

    socket =
      socket
      |> assign(:email_form, email_form)
      |> assign(:email_form_current_password, password)

    {:noreply, socket}
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params
    password_form = to_form(user_params, as: :user)
    {:noreply, assign(socket, :password_form, password_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.user

    socket = assign(socket, :loading_email, true)

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/dashboard/account/confirm_email/#{&1}")
        )

        {:noreply,
         socket
         |> assign(:loading_email, false)
         |> put_flash(:info, "A link to confirm your email change has been sent to the new address.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:loading_email, false)
         |> assign(:email_form, to_form(Map.put(user_params, "action", :validate), as: :user))
         |> put_flash(:error, "Failed to update email. Please check the errors below.")}
    end
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.user

    socket = assign(socket, :loading_password, true)

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:loading_password, false)
         |> assign(:password_form, to_form(%{}, as: :user))
         |> assign(:user, user)
         |> put_flash(:info, "Password updated successfully.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:loading_password, false)
         |> assign(:password_form, to_form(Map.put(user_params, "action", :validate), as: :user))
         |> put_flash(:error, "Failed to update password. Please check the errors below.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-12">
      <div>
        <.header class="text-center">
          Change Email
          <:subtitle>Change your account email address</:subtitle>
        </.header>

        <div class="mt-6">
          <.simple_form
            for={@email_form}
            id="email_form"
            phx-target={@myself}
            phx-submit="update_email"
            phx-change="validate_email"
          >
            <.input field={@email_form[:email]} type="email" label="Email" required />
            <.input
              field={@email_form[:current_password]}
              name="current_password"
              id="current_password_for_email"
              type="password"
              label="Current password"
              value={@email_form_current_password}
              required
            />
            <:actions>
              <.button
                phx-disable-with="Changing..."
                disabled={@loading_email}
                class="w-full md:w-auto"
              >
                <%= if @loading_email do %>
                  <div class="inline-block animate-spin h-4 w-4 mr-2 border-2 border-white rounded-full border-t-transparent" />
                  Changing...
                <% else %>
                  Change Email
                <% end %>
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>

      <div>
        <.header class="text-center">
          Change Password
          <:subtitle>Change your account password</:subtitle>
        </.header>

        <div class="mt-6">
          <.simple_form
            for={@password_form}
            id="password_form"
            phx-target={@myself}
            phx-submit="update_password"
            phx-change="validate_password"
          >
            <.input
              field={@password_form[:current_password]}
              name="current_password"
              type="password"
              label="Current password"
              required
            />
            <.input field={@password_form[:password]} type="password" label="New password" required />
            <.input
              field={@password_form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              required
            />
            <:actions>
              <.button
                phx-disable-with="Changing..."
                disabled={@loading_password}
                class="w-full md:w-auto"
              >
                <%= if @loading_password do %>
                  <div class="inline-block animate-spin h-4 w-4 mr-2 border-2 border-white rounded-full border-t-transparent" />
                  Changing...
                <% else %>
                  Change Password
                <% end %>
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </div>
    </div>
    """
  end
end
