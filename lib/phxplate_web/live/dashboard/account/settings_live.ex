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
      |> assign(:password_form_current_password, nil)
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
    %{"current_password" => password, "user" => user_params} = params
    password_form = to_form(user_params, as: :user)

    socket =
      socket
      |> assign(:password_form, password_form)
      |> assign(:password_form_current_password, password)

    {:noreply, socket}
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

        send(self(), {:flash_msg, :info, "A link to confirm your email change has been sent to the new address."})

        {:noreply,
         socket
         |> assign(:loading_email, false)
         |> assign(:email_form, to_form(%{}, as: :user))
         |> assign(:email_form_current_password, nil)}

      {:error, changeset} ->
        message = cond do
          changeset.errors[:current_password] ->
            "Failed to update email. The current password is not valid."
          changeset.errors[:email] ->
            case changeset.errors[:email] do
              {"did not change", _} -> "The new email must be different from your current email."
              {msg, _} -> "Failed to update email: #{msg}"
            end
          true ->
            "Failed to update email. Please check your inputs and try again."
        end

        send(self(), {:flash_msg, :error, message})

        {:noreply,
         socket
         |> assign(:loading_email, false)
         |> assign(:email_form, to_form(Map.put(user_params, "action", :validate), as: :user))}
    end
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.user

    socket = assign(socket, :loading_password, true)

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        send(self(), {:flash_msg, :info, "Password updated successfully. Please log in again."})

        {:noreply,
         socket
         |> assign(:loading_password, false)
         |> assign(:password_form, to_form(%{}, as: :user))
         |> assign(:password_form_current_password, nil)
         |> assign(:user, user)}

      {:error, changeset} ->
        message = if changeset.errors[:current_password] do
          "Failed to update password. The current password is not valid."
        else
          "Failed to update password. Please check the errors below."
        end

        send(self(), {:flash_msg, :error, message})

        {:noreply,
         socket
         |> assign(:loading_password, false)
         |> assign(:password_form, to_form(Map.put(changeset, :action, :validate), as: :user))
         |> assign(:password_form_current_password, password)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mt-4">
      <div>
        <.header>
          Change Email
          <:subtitle>Change your account email address</:subtitle>
        </.header>

        <div class="-mt-8">
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

      <div class="mt-8">
        <.header>
          Change Password
          <:subtitle>Change your account password</:subtitle>
        </.header>

        <div class="-mt-8">
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
              value={@password_form_current_password}
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
