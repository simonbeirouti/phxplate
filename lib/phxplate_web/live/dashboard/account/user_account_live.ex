defmodule PhxplateWeb.Dashboard.User.UserAccountLive do
  @moduledoc """
  LiveView for managing all aspects of a user's account.

  This view provides a tabbed interface for users to manage their profile information,
  subscription details, account settings, and view their activity history. It serves
  as a container for more specialized components that handle each area of functionality.
  """
  use PhxplateWeb, :live_view
  alias PhxplateWeb.Dashboard.Account.{SettingsLive, BillingLive, ActivitiesLive}
  alias PhxplateWeb.Components.UI.TabsNew
  alias PhxplateWeb.Components.Upload.ImageUploadComponent
  alias Phxplate.{Repo, Accounts}
  alias PhxplateWeb.PageMeta
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

  @doc """
  Initializes the LiveView with user data and available tabs.

  Loads the user's profile, subscription and activity data, and
  sets up the default tab.
  """
  @impl true
  def mount(_params, _session, socket) do
    # Subscribe to platform settings changes and plan changes for the billing component
    if connected?(socket) do
      Phxplate.PubSub.DataSync.subscribe("platform_settings", "all")
      Phxplate.PubSub.DataSync.subscribe("plans", "all")
    end

    user = socket.assigns.current_user |> Repo.preload([:profile, :subscription])
    activities = Phxplate.Tracking.get_user_activities(user.id, 20)

    # Get initial tab titles
    %{subtitle: initial_subtitle} = get_tab_titles("profile")

    # Get the existing profile or create a new one
    profile = user.profile || %Accounts.Profile{user_id: user.id}
    changeset = Accounts.change_profile(profile)

    # Extract social links from profile or use empty map
    social_links = profile.social_links || %{}

    socket =
      socket
      |> PageMeta.assign_metadata(
        title: "User Account",
        description: "Manage your user profile, billing, settings and account activity",
        url: "/dashboard/account"
        )
      |> assign(:user, user)
      |> assign(:activities, activities)
      |> assign(:page_subtitle, initial_subtitle)
      |> assign(:form, to_form(changeset))
      |> assign(:social_links, social_links)
      |> assign(:social_networks, @social_networks)
      |> assign(:form_changed, false)
      # Default selected tab
      |> assign(:selected_tab, "profile")

    {:ok, socket}
  end

  @doc """
  Handles URL parameters to determine the active tab.

  Updates the header subtitle based on the selected tab.
  """
  @impl true
  def handle_params(%{"token" => token}, _url, socket) do
    case Accounts.update_user_email(socket.assigns.current_user, token) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Email changed successfully.")
         |> push_navigate(to: ~p"/dashboard/account?tab=settings")}

      :error ->
        {:noreply,
         socket
         |> put_flash(:error, "Email change link is invalid or it has expired.")
         |> push_navigate(to: ~p"/dashboard/account?tab=settings")}
    end
  end

  def handle_params(params, url, socket) do
    # Update current path for breadcrumbs
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    # Get the tab from params or default to "profile"
    tab = Map.get(params, "tab", "profile")

    # Ensure that the tab is valid or fallback to "profile"
    tab =
      if tab in ["profile", "subscription", "settings", "activities"], do: tab, else: "profile"

    %{subtitle: subtitle} = get_tab_titles(tab)

    {:noreply,
     socket
     |> assign(:page_subtitle, subtitle)
     |> assign(:selected_tab, tab)}
  end

  @impl true
  def handle_event("close_dialog", _, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("tab_changed", %{"tab" => tab}, socket) do
    %{subtitle: subtitle} = get_tab_titles(tab)

    {:noreply,
     socket
     |> assign(:page_subtitle, subtitle)
     |> assign(:selected_tab, tab)
     |> push_patch(to: ~p"/dashboard/account?tab=#{tab}", replace: true)}
  end

  @impl true
  def handle_event("validate", %{"profile" => profile_params}, socket) do
    # Get original profile data for comparison
    profile = socket.assigns.user.profile || %Accounts.Profile{user_id: socket.assigns.user.id}

    original_data = %{
      "first_name" => profile.first_name || "",
      "last_name" => profile.last_name || "",
      "phone" => profile.phone || "",
      "location" => profile.location || "",
      "bio" => profile.bio || "",
      "website" => profile.website || ""
    }

    # Add social links to original data
    original_social_data = @social_networks
    |> Enum.reduce(%{}, fn network, acc ->
      social_key = "social_links_#{network}"
      social_value = if profile.social_links, do: profile.social_links[Atom.to_string(network)] || "", else: ""
      Map.put(acc, social_key, social_value)
    end)

    original_data = Map.merge(original_data, original_social_data)

    # Check if form has changed
    form_changed = profile_params != original_data

    changeset = Accounts.change_profile(profile, profile_params)
    |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset), form_changed: form_changed)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_profile", _params, socket) do
    profile = socket.assigns.user.profile || %Accounts.Profile{user_id: socket.assigns.user.id}
    changeset = Accounts.change_profile(profile)
    social_links = profile.social_links || %{}

    {:noreply, assign(socket, form: to_form(changeset), form_changed: false, social_links: social_links)}
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
  def handle_info({:flash_msg, type, message}, socket) do
    {:noreply, put_flash(socket, type, message)}
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

  # Handle platform settings updates and forward to billing component
  @impl true
  def handle_info({:updated, %{type: :platform_setting}} = msg, socket) do
    # Forward the message to the billing component
    send_update(BillingLive, id: "user_billing", platform_settings_updated: msg)
    {:noreply, socket}
  end

  # Handle plan updates and forward to billing component
  @impl true
  def handle_info({:created, %{type: :plan}} = msg, socket) do
    # Forward the message to the billing component
    send_update(BillingLive, id: "user_billing", plans_updated: msg)
    {:noreply, socket}
  end

  def handle_info({:updated, %{type: :plan}} = msg, socket) do
    # Forward the message to the billing component
    send_update(BillingLive, id: "user_billing", plans_updated: msg)
    {:noreply, socket}
  end

  def handle_info({:deleted, %{type: :plan}} = msg, socket) do
    # Forward the message to the billing component
    send_update(BillingLive, id: "user_billing", plans_updated: msg)
    {:noreply, socket}
  end

  # Catch-all for other PubSub messages we don't need to handle
  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

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
         |> assign(:form_changed, false)
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

  defp clean_params(params) do
    params
    |> Enum.reject(fn {key, _value} -> String.starts_with?(key, "_unused_") end)
    |> Map.new()
  end

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

  defp get_tab_titles(tab) do
    Map.get(@tab_titles, tab, %{
      title: "User Profile",
      subtitle: "Manage your user profile, billing, settings and account activity"
    })
  end

  @doc """
  Renders the user account page with tabbed interface.

  Displays tabs for profile, subscription, settings, and activities,
  and renders the appropriate component for the selected tab.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        <%= get_tab_titles(@selected_tab).title %>
        <:subtitle><%= @page_subtitle %></:subtitle>
      </.header>

      <div class="mt-4">
        <TabsNew.tabs
          :let={builder}
          default={@selected_tab}
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
                    class="text-base"
                    field={@form[:first_name]}
                    type="text"
                    label="First Name"
                    placeholder="John"
                  />
                </div>
                <div>
                  <.input class="text-base" field={@form[:last_name]} type="text" label="Last Name" placeholder="Doe" />
                </div>
              </div>

              <div class="grid grid-cols-2 gap-4">
                <div>
                  <.input class="text-base" field={@form[:phone]} type="tel" label="Phone Number" placeholder="123-456-7890" />
                </div>
                <div>
                  <.input class="text-base" field={@form[:location]} type="text" label="Location" placeholder="New York" />
                </div>
              </div>

              <.textarea class="text-base" field={@form[:bio]} label="Bio" placeholder="Tell us about yourself" />

              <div class="space-y-4">
                <label class="block text-sm font-semibold leading-6">Links</label>
                <div class="grid grid-cols-2 gap-4">
                  <.input
                    class="text-base"
                    field={@form[:website]}
                    type="url"
                    label="Website"
                    placeholder="https://www.yourwebsite.com"
                  />
                  <%= for network <- @social_networks do %>
                    <div>
                      <.input
                        class="text-base"
                        name={"profile[social_links_#{network}]"}
                        value={@social_links[Atom.to_string(network)]}
                        type="url"
                        label={Phoenix.Naming.humanize(network)}
                        placeholder={"Your #{Phoenix.Naming.humanize(network)} URL"}
                      />
                    </div>
                  <% end %>
                </div>
              </div>

              <:actions>
                <%= if @form_changed do %>
                  <div class="flex flex-col gap-3 lg:flex-row lg:gap-3 mb-8 w-full">
                    <.button type="button" variant="outline" phx-click="reset_profile" class="w-full">
                      Reset
                    </.button>
                    <.button type="submit" phx-disable-with="Saving..." class="w-full">
                      Save Changes
                    </.button>
                  </div>
                <% end %>
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
