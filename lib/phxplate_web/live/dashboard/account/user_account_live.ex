defmodule PhxplateWeb.Dashboard.User.UserAccountLive do
  use PhxplateWeb, :live_view
  alias PhxplateWeb.Dashboard.Account.{SettingsLive, BillingLive, ActivitiesLive}
  alias PhxplateWeb.Components.UI.TabsNew
  alias PhxplateWeb.Components.Upload.ImageUploadComponent
  alias Phxplate.{Repo, Accounts}
  require Logger

  @social_networks [:github, :twitter, :linkedin, :facebook, :instagram]

  @tab_titles %{
    "profile" => %{
      title: "User Profile",
      subtitle: "Manage your personal information and profile settings"
    },
    "subscription" => %{
      title: "Subscription Management",
      subtitle: "View and manage your subscription plans and billing information"
    },
    "settings" => %{
      title: "Account Settings",
      subtitle: "Configure your account preferences and security settings"
    },
    "activities" => %{
      title: "Account Activities",
      subtitle: "View your recent account activities and login history"
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user |> Repo.preload([:profile, :subscription])
    activities = Phxplate.Tracking.get_user_activities(user.id, 20)

    # Get initial tab titles
    %{title: initial_title, subtitle: initial_subtitle} = get_tab_titles("profile")

    # Get the existing profile or create a new one
    profile = user.profile || %Accounts.Profile{user_id: user.id}
    changeset = Accounts.change_profile(profile)

    # Extract social links from profile or use empty map
    social_links = profile.social_links || %{}

    socket =
      socket
      |> assign(:user, user)
      |> assign(:activities, activities)
      |> assign(:page_title, initial_title)
      |> assign(:page_subtitle, initial_subtitle)
      |> assign(:form, to_form(changeset))
      |> assign(:social_links, social_links)
      |> assign(:social_networks, @social_networks)

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_dialog", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("tab_changed", %{"tab" => tab}, socket) do
    %{title: title, subtitle: subtitle} = get_tab_titles(tab)

    {:noreply,
     socket
     |> assign(:page_title, title)
     |> assign(:page_subtitle, subtitle)}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", params, socket) do
    if Map.has_key?(params, "profile") do
        handle_profile_save(socket, params["profile"])
      else
    {:noreply, socket}
  end
  end

  @impl true
  def handle_info({:image_uploaded, %{type: :avatar, url: url, old_url: _old_url}}, socket) do
    # Create a profile update map with only the avatar_url field
    profile_update = %{"avatar_url" => url}

    case Accounts.update_profile(socket.assigns.user.profile, profile_update) do
      {:ok, updated_profile} ->
        user = %{socket.assigns.user | profile: updated_profile}

        {:noreply,
        socket
        |> assign(:user, user)
        |> assign(:form, to_form(Accounts.change_profile(updated_profile)))
        |> put_flash(:info, "Avatar uploaded successfully")}

      {:error, _changeset} ->
        # If the profile update failed, try to delete the new image to avoid orphaned files
        if url do
          Task.start(fn -> Phxplate.AWS.S3.delete_file(url) end)
        end

        {:noreply,
        socket
        |> put_flash(:error, "Failed to update profile with new avatar")}
    end
  end

  @impl true
  def handle_info({:image_uploaded_error, %{error: error_msg}}, socket) do
    {:noreply,
     socket
     |> put_flash(:error, error_msg)}
  end

  defp handle_profile_save(socket, profile_params) do
    profile_params = clean_params(profile_params)
    social_links = extract_social_links(profile_params)
    profile_params = Map.put(profile_params, "social_links", social_links)

    case Accounts.update_user_profile(socket.assigns.user, profile_params) do
      {:ok, updated_profile} ->
        user = %{socket.assigns.user | profile: updated_profile}

        {:noreply,
        socket
        |> assign(:user, user)
        |> assign(:social_links, social_links)
        |> assign(:form, to_form(Accounts.change_profile(updated_profile)))
         |> put_flash(:info, "Profile updated successfully!")}

      {:error, changeset} ->
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

        {:noreply,
        socket
        |> assign(:form, to_form(changeset))
         |> put_flash(:error, error_message)}
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

  # Get the title and subtitle for a specific tab
  defp get_tab_titles(tab) do
    Map.get(@tab_titles, tab, %{
      title: "User Profile",
      subtitle: "Manage your user profile, billing, settings and account activity"
    })
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        {@page_title}
        <:subtitle>{@page_subtitle}</:subtitle>
      </.header>

      <div class="mt-4">
        <TabsNew.tabs
          :let={builder}
          default="profile"
          id="user_tabs"
          class="w-full"
          on_change="tab_changed"
        >
          <TabsNew.tabs_list class="grid w-full lg:w-1/2 grid-cols-4">
            <TabsNew.tabs_trigger value="profile" builder={builder}>
              Profile
            </TabsNew.tabs_trigger>

            <TabsNew.tabs_trigger value="subscription" builder={builder}>
              Subscription
            </TabsNew.tabs_trigger>

            <TabsNew.tabs_trigger value="settings" builder={builder}>
              Settings
            </TabsNew.tabs_trigger>

            <TabsNew.tabs_trigger value="activities" builder={builder}>
              Activities
            </TabsNew.tabs_trigger>
          </TabsNew.tabs_list>

          <TabsNew.tabs_content value="profile">
              <div class="flex flex-col items-center gap-4">
              <.live_component
                module={ImageUploadComponent}
                id="profile-avatar"
                type={:avatar}
                image_url={@user.profile.avatar_url}
                entity_type={:user}
                entity_id={@user.id}
                on_upload_complete="image_uploaded"
                        />
                      </div>
            <.simple_form for={@form} id="profile-form" phx-change="validate" phx-submit="save">
              <div class="grid grid-cols-2 gap-4">
                <div>
                  <.input
                    field={@form[:first_name]}
                    type="text"
                    label="First Name"
                    phx-debounce="blur"
                  />
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
                <.button phx-disable-with="Saving..." class="w-full md:w-auto mb-8">
                  Save Profile
                </.button>
              </:actions>
            </.simple_form>
          </TabsNew.tabs_content>

          <TabsNew.tabs_content value="subscription">
            <.live_component module={BillingLive} id="user_billing" user={@user} />
          </TabsNew.tabs_content>

          <TabsNew.tabs_content value="settings">
            <.live_component module={SettingsLive} id="user_settings" user={@user} />
          </TabsNew.tabs_content>

          <TabsNew.tabs_content value="activities">
            <.live_component
              module={ActivitiesLive}
              id="user_activities"
              user={@user}
              activities={@activities}
            />
          </TabsNew.tabs_content>
        </TabsNew.tabs>
      </div>
    </div>
    """
  end
end
