defmodule PhxplateWeb.Components.DashboardLayout do
  @moduledoc false
  use PhxplateWeb, :live_component

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:show_support, fn -> false end)
      |> assign_new(:support_mode, fn -> "dialog" end)

    ~H"""
    <div phx-hook="FeatureRequestEvents" id={@id}>
      <.render_dashboard_layout
        layout_data={@layout_data}
        flash={@flash}
        inner_content={@inner_content}
        show_support={@show_support}
        myself={@myself}
        support_mode={@support_mode}
      />
      <.dialog_drawer_wrapper
        id="support-modal"
        show={@show_support}
        mode={@support_mode}
        on_cancel={JS.push("toggle_support", target: @myself)}
        hook="DialogDrawerMode"
        myself={@myself}
        name="Feature Request or Feedback!"
        description="Submit a feature request or provide feedback"
      >
        <.live_component
          module={PhxplateWeb.Dashboard.FeatureRequestLive}
          id="feature-request"
          current_user={@layout_data.user}
          parent_id={@id}
        />
      </.dialog_drawer_wrapper>
    </div>
    """
  end

  def render_dashboard_layout(assigns) do
        # Get current sidebar state with fallback
    current_sidebar_state = assigns[:current_sidebar_state] ||
      (if assigns[:layout_data] && assigns.layout_data[:user] do
        user = Phxplate.Accounts.get_user!(assigns.layout_data.user.id)
        Phxplate.Accounts.get_user_sidebar_state(user)
      else
        "expanded"
      end)

    assigns = assign(assigns, :current_sidebar_state, current_sidebar_state)

    ~H"""
    <.sidebar_provider>
      <.sidebar_main data={@layout_data} myself={@myself} current_sidebar_state={@current_sidebar_state}></.sidebar_main>
      <.sidebar_inset>
        <%= if @layout_data.user do %>
          <.live_component
            module={PhxplateWeb.UserSessionHandlerLive}
            id="user-session-handler"
            current_user={@layout_data.user}
          />
        <% end %>

        <header class="flex h-16 shrink-0 items-center border-b gap-2 pl-2">
          <button
            type="button"
            id="mobile-menu-button"
            class="md:hidden inline-flex items-center justify-center rounded-md p-2 text-gray-700 hover:bg-gray-100 hover:text-gray-900"
            phx-hook="NavMenu"
          >
            <span class="sr-only">Open main menu</span>
            <Lucideicons.menu class="h-6 w-6" id="menu-icon" />
            <Lucideicons.x class="h-6 w-6 hidden" id="close-icon" />
          </button>

          <.sidebar_trigger target={@myself} class="pl-2 hidden md:block">
            <Lucideicons.panel_left class="w-4 h-4" />
          </.sidebar_trigger>

          <.separator orientation="vertical" class="mr-2 h-4" />
          <.breadcrumb class="ml-0 md:ml-2">
            <.breadcrumb_list>
              <%= for {item, idx} <- Enum.with_index(dashboard_breadcrumbs(@layout_data.current_path)) do %>
                <.breadcrumb_item>
                  <.breadcrumb_link href={item.href}>
                    {item.label}
                  </.breadcrumb_link>
                </.breadcrumb_item>
                <.breadcrumb_separator
                  :if={idx < length(dashboard_breadcrumbs(@layout_data.current_path)) - 1}
                  class="block"
                />
              <% end %>
            </.breadcrumb_list>
          </.breadcrumb>

          <div class="flex-grow" />
          <button class="mr-2 p-3 border border-gray-50 shadow-sm rounded-md hover:bg-gray-100" phx-click="toggle_support" phx-target={@myself}>
            <Lucideicons.bell_plus class="w-4 h-4" />
            <span class="sr-only">Support & Feature Requests</span>
          </button>
        </header>

        <div
          id="mobile-menu"
          class="hidden md:hidden absolute w-full bg-white border-b mt-16 shadow-lg z-50"
        >
          <div class="space-y-1 px-2 pb-3 pt-2">
            <.mobile_nav_main groups={@layout_data.navGroups} />
            <.mobile_nav_projects companies={@layout_data.companies} />
            <.mobile_nav_bookmarked bookmarked={@layout_data.bookmarked} />
            <.mobile_nav_user user={@layout_data.user} />
          </div>
        </div>

        <main class="flex-1">
          <div class="p-4">
            <.flash_group flash={@flash} />
            {@inner_content}
          </div>
        </main>
      </.sidebar_inset>
    </.sidebar_provider>
    """
  end

  attr :data, :map, required: true
  attr :myself, :any, required: true
  attr :current_sidebar_state, :string, required: true
  slot :inner_block

  def sidebar_main(assigns) do
    # Create a user-specific sidebar ID for persisting state
    sidebar_id = "main-sidebar-#{assigns.data.user.id}"
    # Use the current state from the component (which is already loaded from DB)
    current_state = assigns.current_sidebar_state
    assigns = assign(assigns, %{sidebar_id: sidebar_id, current_state: current_state})

    ~H"""
    <.sidebar
      collapsible="icon"
      id={@sidebar_id}
      state={@current_state}
      target={@myself}
    >
      <.sidebar_header>
        <.nav_user user={@data.user} state={@current_state} />
      </.sidebar_header>
      <.sidebar_content class="overflow-visible">
        <.nav_main groups={@data.navGroups} state={@current_state} />
        <.nav_projects
          :if={length(@data.companies) >= 1}
          label="Companies"
          projects={@data.companies}
          state={@current_state}
        />
        <.nav_projects
          :if={length(@data.bookmarked) >= 1}
          label="Bookmarked"
          projects={@data.bookmarked}
          state={@current_state}
        />
      </.sidebar_content>
      <.sidebar_rail target={@myself} />
    </.sidebar>
    """
  end

  attr :groups, :list, required: true
  attr :state, :string, required: true

  def nav_main(assigns) do
    ~H"""
    <%= for group <- @groups do %>
      <.sidebar_group>
        <.sidebar_group_label>
          {group.label}
        </.sidebar_group_label>
        <.sidebar_menu :for={item <- group.items}>
          <.sidebar_menu_item>
            <div :if={@state == "collapsed"}>
              <.dropdown_menu class="block">
                <.as_child
                  tag={&dropdown_menu_trigger/1}
                  child={&sidebar_menu_button/1}
                  state={@state}
                  class="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
                >
                  <.dynamic :if={not is_nil(item.icon)} tag={item.icon} />
                  <span class="sr-only">
                    {item.title}
                  </span>
                </.as_child>
                <.dropdown_menu_content
                  class="min-w-56 rounded-lg"
                  side="right"
                  align="start"
                >
                  <.menu>
                    <.link :for={sub_item <- item.items} href={sub_item.url}>
                      <.menu_item>
                        {sub_item.title}
                      </.menu_item>
                    </.link>
                  </.menu>
                </.dropdown_menu_content>
              </.dropdown_menu>
            </div>

            <div :if={@state != "collapsed"}>
              <.as_child tag={&collapsible_trigger/1} child={&sidebar_menu_button/1} state={@state}>
                <.dynamic :if={not is_nil(item.icon)} tag={item.icon} />
                <span>
                  {item.title}
                </span>
              </.as_child>
              <.sidebar_menu_sub>
                <.sidebar_menu_sub_item :for={sub_item <- item.items}>
                  <.as_child tag={&sidebar_menu_sub_button/1} child="a" href={sub_item.url}>
                    <span>
                      {sub_item.title}
                    </span>
                  </.as_child>
                </.sidebar_menu_sub_item>
              </.sidebar_menu_sub>
            </div>
          </.sidebar_menu_item>
        </.sidebar_menu>
      </.sidebar_group>
    <% end %>
    """
  end

  attr :label, :string, required: true
  attr :projects, :list, required: true
  attr :state, :string, required: true

  def nav_projects(assigns) do
    ~H"""
    <.sidebar_group>
      <.sidebar_group_label>
        {@label}
      </.sidebar_group_label>
      <.sidebar_menu>
        <.sidebar_menu_item :for={project <- @projects}>
          <a
            href={
              cond do
                project[:is_owner] -> ~p"/dashboard/admin/companies/#{project.id}"
                project[:is_employee] -> ~p"/dashboard/companies/#{project.id}"
                true -> ~p"/companies/#{project.id}"
              end
            }
            class="truncate"
          >
            <.sidebar_menu_button class="flex items-center gap-2" state={@state}>
              <.avatar class="h-8 w-8 rounded-lg -ml-2">
                <.avatar_image src={project.logo} alt={project.name} />
                <.avatar_fallback class="rounded-lg">
                  {String.slice(project.name, 0, 2)}
                </.avatar_fallback>
              </.avatar>
              <span class="max-lg:hidden">{project.name}</span>
            </.sidebar_menu_button>
          </a>
        </.sidebar_menu_item>
      </.sidebar_menu>
    </.sidebar_group>
    """
  end

  attr :user, :map, required: true
  attr :state, :string, required: true

  def nav_user(assigns) do
    ~H"""
    <.sidebar_menu>
      <.sidebar_menu_item>
        <.dropdown_menu class="block">
          <.as_child
            tag={&dropdown_menu_trigger/1}
            child={&sidebar_menu_button/1}
            size="lg"
            class="data-[state=open]:bg-sidebar-accent data-[state=open]:text-sidebar-accent-foreground"
            state={@state}
          >
            <.avatar class="h-8 w-8 rounded-lg -ml-2">
              <.avatar_image src={@user.avatar} alt={@user.name} />
              <.avatar_fallback class="rounded-lg">
                {String.slice(@user.name, 0, 2)}
              </.avatar_fallback>
            </.avatar>
            <div class="grid flex-1 text-left text-sm leading-tight ml-2 max-lg:hidden">
              <span class="truncate font-semibold">
                {@user.name}
              </span>
              <span class="truncate text-xs">
                {@user.email}
              </span>
            </div>
            <Lucideicons.chevrons_up_down class="ml-auto size-4 max-lg:hidden" />
          </.as_child>
          <.dropdown_menu_content
            class="w-[--radix-dropdown-menu-trigger-width] min-w-56 rounded-lg"
            side="bottom"
            align="start"
          >
            <.menu>
              <%= if @user.role == :basic do %>
                <dropdownmenugroup>
                  <.link href={~p"/dashboard/account?tab=subscription"}>
                    <.menu_item>
                      <Lucideicons.sparkles class="w-4 h-4 mr-2" /> Upgrade to Pro
                    </.menu_item>
                  </.link>
                </dropdownmenugroup>
                <.menu_separator></.menu_separator>
              <% end %>
              <.link href={~p"/logout"} method="delete">
                <.menu_item>
                  <Lucideicons.log_out class="w-4 h-4 mr-2" /> Log out
                </.menu_item>
              </.link>
            </.menu>
          </.dropdown_menu_content>
        </.dropdown_menu>
      </.sidebar_menu_item>
    </.sidebar_menu>
    """
  end

  attr :groups, :list, required: true

  def mobile_nav_main(assigns) do
    ~H"""
    <%= for group <- @groups do %>
      <div class="space-y-1">
        <div class="px-3 py-2 text-sm font-medium text-gray-500">{group.label}</div>
        <%= for item <- group.items do %>
          <div class="space-y-1">
            <button
              type="button"
              class="flex w-full items-center justify-between rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
              phx-click={JS.toggle(to: "#mobile-submenu-#{id(item.title)}")}
            >
              <div class="flex items-center">
                <.dynamic :if={not is_nil(item.icon)} tag={item.icon} class="mr-2 h-4 w-4" />
                <span>{item.title}</span>
              </div>
              <Lucideicons.chevron_right class="h-4 w-4 transition-transform duration-200 group-data-[state=open]:rotate-90" />
            </button>
            <div id={"mobile-submenu-#{id(item.title)}"} class="hidden space-y-1 pl-4">
              <%= for sub_item <- item.items do %>
                <.link
                  href={sub_item.url}
                  class="block rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
                >
                  {sub_item.title}
                </.link>
              <% end %>
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  attr :companies, :list, required: true

  def mobile_nav_projects(assigns) do
    ~H"""
    <div :if={length(@companies) >= 1} class="space-y-1">
      <div class="px-3 py-2 text-sm font-medium text-gray-500">Companies</div>
      <%= for item <- @companies do %>
        <.link
          href={
            if item[:is_owner],
              do: ~p"/dashboard/admin/companies/#{item.id}",
              else: ~p"/dashboard/companies/#{item.id}"
          }
          class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
        >
          <.avatar class="h-8 w-8 rounded-lg">
            <.avatar_image src={item.logo} alt={item.name} />
            <.avatar_fallback class="rounded-lg">
              {item.name}
            </.avatar_fallback>
          </.avatar>
          <span class="ml-2">{item.name}</span>
        </.link>
      <% end %>
    </div>
    """
  end

  attr :bookmarked, :list, required: true

  def mobile_nav_bookmarked(assigns) do
    ~H"""
    <div :if={length(@bookmarked) >= 1} class="space-y-1">
      <div class="px-3 py-2 text-sm font-medium text-gray-500">Bookmarked</div>
      <%= for item <- @bookmarked do %>
        <.link
          href={
            cond do
              item[:is_owner] -> ~p"/dashboard/admin/companies/#{item.id}"
              item[:is_employee] -> ~p"/dashboard/companies/#{item.id}"
              true -> ~p"/companies/#{item.id}"
            end
          }
          class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
        >
          <.avatar class="h-8 w-8 rounded-lg">
            <.avatar_image src={item.logo} alt={item.name} />
            <.avatar_fallback class="rounded-lg">
              {item.name}
            </.avatar_fallback>
          </.avatar>
          <span class="ml-2">{item.name}</span>
        </.link>
      <% end %>
    </div>
    """
  end

  attr :user, :map, required: true

  def mobile_nav_user(assigns) do
    ~H"""
    <div class="space-y-1">
      <div class="px-3 py-2 text-sm font-medium text-gray-500">Account</div>
      <.link
        href={~p"/dashboard/invites"}
        class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
      >
        <Lucideicons.mail class="mr-2 h-4 w-4" />
        <span>Invites</span>
      </.link>
      <.link
        href={~p"/dashboard/account"}
        class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
      >
        <Lucideicons.settings class="mr-2 h-4 w-4" />
        <span>Account</span>
      </.link>
      <.link
        href={~p"/logout"}
        method="delete"
        class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
      >
        <Lucideicons.log_out class="mr-2 h-4 w-4" />
        <span>Log out</span>
      </.link>
    </div>
    """
  end

  def dashboard_breadcrumbs("/dashboard" <> rest) do
    segments =
      rest
      |> String.trim_leading("/")
      |> String.split("/", trim: true)

    base = [%{label: "Dashboard", href: "/dashboard"}]

    Enum.reduce(segments, {base, "/dashboard"}, fn seg, {acc, path} ->
      next_path = path <> "/" <> seg

      label =
        seg
        |> String.replace("_", " ")
        |> String.replace("-", " ")
        |> String.split()
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      {acc ++ [%{label: label, href: next_path}], next_path}
    end)
    |> elem(0)
  end

  def dashboard_breadcrumbs(_), do: [%{label: "Dashboard", href: "/dashboard"}]

  def handle_event("toggle_support", _params, socket) do
    {:noreply, assign(socket, :show_support, !socket.assigns.show_support)}
  end

    def handle_event("toggle_sidebar_state", _params, socket) do
    user_data = socket.assigns.layout_data.user
    # Get the full User struct
    user = Phxplate.Accounts.get_user!(user_data.id)

    # Get current state from socket or database as fallback
    current_state = socket.assigns[:current_sidebar_state] ||
                   Phxplate.Accounts.get_user_sidebar_state(user)
    new_state = if current_state == "expanded", do: "collapsed", else: "expanded"

    case Phxplate.Accounts.update_user_sidebar_state(user, new_state) do
      {:ok, _updated_user} ->
        # Update the local state as well
        {:noreply, assign(socket, :current_sidebar_state, new_state)}
      {:error, _changeset} ->
        # Log error but don't fail the request
        require Logger
        Logger.warning("Failed to update sidebar state for user #{user_data.id}: #{new_state}")
        {:noreply, socket}
    end
  end

  def handle_event("update_sidebar_state", %{"state" => state}, socket) when state in ["expanded", "collapsed"] do
    user_data = socket.assigns.layout_data.user
    # Get the full User struct
    user = Phxplate.Accounts.get_user!(user_data.id)

    case Phxplate.Accounts.update_user_sidebar_state(user, state) do
      {:ok, _updated_user} ->
        # Update the local state as well
        {:noreply, assign(socket, :current_sidebar_state, state)}
      {:error, _changeset} ->
        # Log error but don't fail the request
        require Logger
        Logger.warning("Failed to update sidebar state for user #{user_data.id}: #{state}")
        {:noreply, assign(socket, :current_sidebar_state, state)}
    end
  end

  def handle_event("update_sidebar_state", _params, socket) do
    # Invalid state, ignore
    {:noreply, socket}
  end

  def handle_event("set_screen_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :support_mode, mode)}
  end

  def handle_event("feature_request_success", %{"message" => message}, socket) do
    socket =
      socket
      |> assign(:show_support, false)
      |> put_flash(:info, message)

    {:noreply, socket}
  end

  def handle_event("feature_request_error", %{"message" => message}, socket) do
    socket = put_flash(socket, :error, message)
    {:noreply, socket}
  end

    def update(assigns, socket) do
    # Preserve current_sidebar_state if it exists, otherwise let render_dashboard_layout handle it
    filtered_assigns = Map.drop(assigns, [:flash])

    if Map.has_key?(socket.assigns, :current_sidebar_state) do
      filtered_assigns = Map.drop(filtered_assigns, [:current_sidebar_state])
      {:ok, assign(socket, filtered_assigns)}
    else
      {:ok, assign(socket, filtered_assigns)}
    end
  end

  def handle_info({:feature_request_success, message}, socket) do
    socket =
      socket
      |> assign(:show_support, false)
      |> put_flash(:info, message)

    {:noreply, socket}
  end

  def handle_info({:feature_request_error, message}, socket) do
    socket = put_flash(socket, :error, message)
    {:noreply, socket}
  end
end
