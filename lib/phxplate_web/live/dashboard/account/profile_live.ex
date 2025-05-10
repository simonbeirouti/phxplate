defmodule PhxplateWeb.Dashboard.Account.ProfileLive do
  use PhxplateWeb, :live_component
  alias Phxplate.Accounts
  require Logger

  @social_networks [:github, :twitter, :linkedin, :facebook, :instagram]

  @impl true
  def update(%{user: user} = assigns, socket) do
    # Get the existing profile or create a new one
    profile = user.profile || %Accounts.Profile{user_id: user.id}
    changeset = Accounts.change_profile(profile)

    # Extract social links from profile or use empty map
    social_links = profile.social_links || %{}

    socket =
      socket
      |> assign(assigns)
      |> assign(:form, to_form(changeset))
      |> assign(:loading, false)
      |> assign(:social_links, social_links)
      |> assign(:social_networks, @social_networks)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"profile" => profile_params}, socket) do
    # Clean up params by removing _unused_ fields
    profile_params = clean_params(profile_params)

    # Extract and validate social links
    social_links = extract_social_links(profile_params)
    profile_params = Map.put(profile_params, "social_links", social_links)

    profile = socket.assigns.user.profile || %Accounts.Profile{user_id: socket.assigns.user.id}

    form =
      profile
      |> Accounts.change_profile(profile_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form, social_links: social_links)}
  end

  def handle_event("save", %{"profile" => profile_params}, socket) do
    Logger.debug("Starting profile save with params: #{inspect(profile_params)}")

    # Clean up params by removing _unused_ fields
    profile_params = clean_params(profile_params)
    Logger.debug("Cleaned profile params: #{inspect(profile_params)}")

    # Extract and validate social links
    social_links = extract_social_links(profile_params)
    profile_params = Map.put(profile_params, "social_links", social_links)
    Logger.debug("Profile params with social links: #{inspect(profile_params)}")

    case Accounts.update_user_profile(socket.assigns.user, profile_params) do
      {:ok, updated_profile} ->
        Logger.debug("Profile updated successfully for user: #{updated_profile.user_id}")
        # Send success message to parent and update socket with new profile
        send(self(), {:flash_msg, :info, "Profile updated successfully!"})
        # Also send the updated profile to parent for state update
        send(self(), {:profile_updated, updated_profile})
        Logger.debug("Sent success flash message and profile update to parent")

        {:noreply,
         socket
         |> assign(:social_links, social_links)
         |> assign(:form, to_form(Accounts.change_profile(updated_profile)))
         |> assign(:loading, false)}

      {:error, changeset} ->
        Logger.debug("Profile update failed with errors: #{inspect(changeset.errors)}")
        # Extract error messages from changeset
        error_message =
          case changeset.errors do
            [] ->
              "Failed to update profile. Please check your input and try again."

            errors ->
              errors
              |> Enum.map(fn {field, {msg, _}} ->
                "#{Phoenix.Naming.humanize(field)} #{msg}"
              end)
              |> Enum.join(". ")
          end

        Logger.debug("Generated error message: #{error_message}")

        # Send error message to parent and update socket
        send(self(), {:flash_msg, :error, error_message})
        Logger.debug("Sent error flash message to parent")

        {:noreply,
         socket
         |> assign(:form, to_form(changeset))
         |> assign(:loading, false)}
    end
  end

  # Clean params by removing _unused_ fields
  defp clean_params(params) do
    params
    |> Enum.reject(fn {key, _value} -> String.starts_with?(key, "_unused_") end)
    |> Map.new()
  end

  # Extract social links from params and validate URLs
  defp extract_social_links(params) do
    @social_networks
    |> Enum.reduce(%{}, fn network, acc ->
      case params["social_links_#{network}"] do
        url when is_binary(url) and url != "" ->
          Map.put(acc, Atom.to_string(network), url)

        _ ->
          acc
      end
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="profile-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="flex justify-center">
          <div class="w-32 h-32 relative">
            <div class="w-full h-full rounded-full overflow-hidden border-2 border-gray-200">
              <img
                src={@form[:avatar_url].value || "/images/default-avatar.png"}
                alt="Profile avatar"
                class="w-full h-full object-cover"
              />
              <div class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50 opacity-0 hover:opacity-100 transition-opacity cursor-pointer rounded-full">
                <div class="relative">
                  <Lucideicons.camera class="w-8 h-8 text-white absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none" />
                  <input
                    type="file"
                    name={@form[:avatar_url].name}
                    accept="image/*"
                    class="sr-only"
                    phx-change="upload_avatar"
                    phx-target={@myself}
                  />
                </div>
              </div>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <.input field={@form[:first_name]} type="text" label="First Name" phx-debounce="blur" />
          </div>
          <div>
            <.input field={@form[:last_name]} type="text" label="Last Name" phx-debounce="blur" />
          </div>
        </div>

        <div class="grid grid-cols-2 gap-4">
          <div>
            <.input field={@form[:phone]} type="tel" label="Phone Number" phx-debounce="blur" />
          </div>
          <div>
            <.input field={@form[:location]} type="text" label="Location" phx-debounce="blur" />
          </div>
        </div>

        <.input field={@form[:bio]} type="textarea" label="Bio" phx-debounce="blur" />

        <div class="space-y-4">
          <label class="block text-sm font-semibold leading-6">Links</label>
          <div class="grid grid-cols-2 gap-4">
            <.input
              field={@form[:website]}
              type="url"
              label="Website"
              phx-debounce="blur"
              placeholder="https://"
            />
            <%= for network <- @social_networks do %>
              <div>
                <.input
                  name={"profile[social_links_#{network}]"}
                  value={@social_links[Atom.to_string(network)]}
                  type="url"
                  label={Phoenix.Naming.humanize(network)}
                  phx-debounce="blur"
                  placeholder={"Your #{Phoenix.Naming.humanize(network)} URL"}
                />
              </div>
            <% end %>
          </div>
        </div>

        <:actions>
          <.button phx-disable-with="Saving..." disabled={@loading} class="w-full md:w-auto mb-8">
            <%= if @loading do %>
              <div class="inline-block animate-spin h-4 w-4 mr-2 border-2 border-white rounded-full border-t-transparent" />
              Saving...
            <% else %>
              Save Profile
            <% end %>
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
