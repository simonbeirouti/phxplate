defmodule PhxplateWeb.Dashboard.SuperAdmin.PlatformSettingsLive do
  @moduledoc """
  LiveView for managing platform-wide settings.

  This view allows super admins to configure platform-wide settings
  such as enabling/disabling subscriptions and single purchase products.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.Subscriptions
  alias PhxplateWeb.PageMeta
  alias Phxplate.PubSub.DataSync

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      DataSync.subscribe("platform_settings", "all")
    end

    platform_settings = Subscriptions.list_platform_settings()

    {:ok,
     socket
     |> assign(:platform_settings, platform_settings)
     |> assign(:loading, false)
     |> PageMeta.assign_metadata(
       title: "Platform Settings",
       description: "Configure platform-wide settings and features",
       url: "/dashboard/super_admin/platform-settings"
     )}
  end

  @impl true
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = Phoenix.Component.update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:noreply, socket}
  end

    @impl true
  def handle_event("toggle_setting", %{"key" => key}, socket) do
    current_user = socket.assigns.current_user

    # Find the current setting and toggle its value
    current_setting = Enum.find(socket.assigns.platform_settings, &(&1.key == key))
    new_value = if current_setting, do: !current_setting.value, else: true

    socket = assign(socket, :loading, true)

    # Debug output
    IO.inspect({key, current_setting && current_setting.value, new_value}, label: "Toggle setting")

    case Subscriptions.update_platform_setting(key, new_value, current_user) do
      {:ok, _setting} ->
        platform_settings = Subscriptions.list_platform_settings()

        {:noreply,
         socket
         |> assign(:platform_settings, platform_settings)
         |> assign(:loading, false)
         |> put_flash(:info, "Platform setting updated successfully")}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "You are not authorized to modify platform settings")}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Platform setting not found")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Failed to update platform setting")}
    end
  end

  @impl true
  def handle_info({:updated, %{type: :platform_setting}}, socket) do
    # Reload settings when updated via PubSub
    platform_settings = Subscriptions.list_platform_settings()
    {:noreply, assign(socket, :platform_settings, platform_settings)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1">
      <.header>
        Platform Settings
        <:subtitle>Configure platform-wide features and settings</:subtitle>
      </.header>

      <div class="mt-8 max-w-4xl">
        <div class="bg-white shadow rounded-lg">
          <div class="px-6 py-4 border-b border-gray-200">
            <h3 class="text-lg font-medium text-gray-900">Product Types</h3>
            <p class="mt-1 text-sm text-gray-600">
              Control which product types are available across the platform
            </p>
          </div>

          <div class="px-6 py-4 space-y-6">
            <%= for setting <- @platform_settings do %>
              <div class="flex items-center justify-between">
                <div class="flex-1">
                  <h4 class="text-sm font-medium text-gray-900">
                    {format_setting_title(setting.key)}
                  </h4>
                  <p class="text-sm text-gray-600">
                    {setting.description}
                  </p>
                </div>
                                <div class="ml-6">
                  <button
                    type="button"
                    role="switch"
                    data-state={if(setting.value, do: "checked", else: "unchecked")}
                    phx-click="toggle_setting"
                    phx-value-key={setting.key}
                    disabled={@loading}
                    class={[
                      "group/switch inline-flex h-6 w-11 shrink-0 cursor-pointer items-center rounded-full border-2 border-transparent transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 focus-visible:ring-offset-background disabled:cursor-not-allowed disabled:opacity-50",
                      if(setting.value,
                        do: "bg-black",
                        else: "bg-gray-200"
                      )
                    ]}
                  >
                    <span class={[
                      "pointer-events-none block h-5 w-5 rounded-full bg-white shadow-lg ring-0 transition-transform",
                      if(setting.value,
                        do: "translate-x-5",
                        else: "translate-x-0"
                      )
                    ]}>
                    </span>
                  </button>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div class="mt-8 grid grid-cols-1 md:grid-cols-2 gap-6">
          <%= for setting <- @platform_settings do %>
            <div class={[
              "border rounded-lg p-4",
              if(setting.value,
                do: "border-green-200 bg-green-50",
                else: "border-gray-200 bg-gray-50"
              )
            ]}>
              <div class="flex items-center justify-between">
                <h4 class="text-sm font-medium text-gray-900">
                  {format_setting_title(setting.key)}
                </h4>
                <span class={[
                  "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium",
                  if(setting.value,
                    do: "bg-green-100 text-green-800",
                    else: "bg-gray-100 text-gray-800"
                  )
                ]}>
                  {if setting.value, do: "Enabled", else: "Disabled"}
                </span>
              </div>
              <p class="mt-2 text-xs text-gray-600">
                Last updated: {Calendar.strftime(setting.updated_at, "%B %d, %Y at %H:%M")}
              </p>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper function to format setting keys into readable titles
  defp format_setting_title(key) do
    key
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end
end
