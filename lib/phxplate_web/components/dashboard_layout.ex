defmodule PhxplateWeb.Components.DashboardLayout do
  @moduledoc false
  use PhxplateWeb, :live_component
  use SaladUI

  import Lucideicons, except: [import: 1, quote: 1, menu: 1, link: 1]

  def render(assigns) do
    ~H"""
    <div>
      <.render_dashboard_layout layout_data={@layout_data} flash={@flash} inner_content={@inner_content} />
    </div>
    """
  end

  def render_dashboard_layout(assigns) do
    ~H"""
    <.sidebar_provider>
      <.sidebar_main data={@layout_data}></.sidebar_main>
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

          <.sidebar_trigger target="main-sidebar" class="pl-2 hidden md:block">
            <Lucideicons.panel_left class="w-4 h-4" />
          </.sidebar_trigger>

          <.separator orientation="vertical" class="mr-2 h-4" />
          <.breadcrumb>
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
        </header>

        <div id="mobile-menu" class="hidden md:hidden absolute w-full bg-white border-b mt-16 shadow-lg z-50">
          <div class="space-y-1 px-2 pb-3 pt-2">
            <.mobile_nav_main items={@layout_data.navMain} />
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

  def sidebar_main(assigns) do
    ~H"""
    <.sidebar collapsible="icon" id="main-sidebar" state="expanded">
      <.sidebar_header>
        <.nav_user user={@data.user} />
      </.sidebar_header>
      <.sidebar_content>
        <.nav_main items={@data.navMain} />
        <.nav_projects :if={length(@data.companies) >= 1} label="Companies" projects={@data.companies} />
        <.nav_projects
          :if={length(@data.bookmarked) >= 1}
          label="Bookmarked"
          projects={@data.bookmarked}
        />
      </.sidebar_content>
      <.sidebar_rail />
    </.sidebar>
    """
  end

  def nav_main(assigns) do
    ~H"""
    <.sidebar_group>
      <.sidebar_group_label>
        Platform
      </.sidebar_group_label>
      <.sidebar_menu :for={item <- @items}>
        <.sidebar_menu_item>
          <.as_child tag={&collapsible_trigger/1} child={&sidebar_menu_button/1} tooltip={item.title}>
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
        </.sidebar_menu_item>
      </.sidebar_menu>
    </.sidebar_group>
    """
  end

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
            <.sidebar_menu_button class="flex items-center gap-2">
              <.avatar class="h-8 w-8 rounded-lg -ml-2">
                <.avatar_image src={project.logo} alt={project.name} />
                <.avatar_fallback class="rounded-lg">
                  {String.slice(project.name, 0, 2)}
                </.avatar_fallback>
              </.avatar>
              {project.name}
            </.sidebar_menu_button>
          </a>
        </.sidebar_menu_item>
      </.sidebar_menu>
    </.sidebar_group>
    """
  end

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
          >
            <.avatar class="h-8 w-8 rounded-lg -ml-2">
              <.avatar_image src={@user.avatar} alt={@user.name} />
              <.avatar_fallback class="rounded-lg">
                {String.slice(@user.name, 0, 2)}
              </.avatar_fallback>
            </.avatar>
            <div class="grid flex-1 text-left text-sm leading-tight ml-2">
              <span class="truncate font-semibold">
                {@user.name}
              </span>
              <span class="truncate text-xs">
                {@user.email}
              </span>
            </div>
            <.chevrons_up_down class="ml-auto size-4" />
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
                      <.sparkles class="w-4 h-4 mr-2" /> Upgrade to Pro
                    </.menu_item>
                  </.link>
                </dropdownmenugroup>
                <.menu_separator></.menu_separator>
              <% end %>
              <dropdownmenugroup>
                <.link href={~p"/dashboard/invites"}>
                  <.menu_item>
                    <Lucideicons.mail class="w-4 h-4 mr-2" /> Invites
                  </.menu_item>
                </.link>
              </dropdownmenugroup>
              <dropdownmenugroup>
                <.link href={~p"/dashboard/account"}>
                  <.menu_item>
                    <Lucideicons.settings class="w-4 h-4 mr-2" /> Account
                  </.menu_item>
                </.link>
              </dropdownmenugroup>
              <.menu_separator></.menu_separator>
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

  def mobile_nav_main(assigns) do
    ~H"""
    <div class="space-y-1">
      <div class="px-3 py-2 text-sm font-medium text-gray-500">Platform</div>
      <%= for item <- @items do %>
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
    """
  end

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
      label = seg |> String.replace("_", " ") |> String.split() |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
      {acc ++ [%{label: label, href: next_path}], next_path}
    end)
    |> elem(0)
  end

  def dashboard_breadcrumbs(_), do: [%{label: "Dashboard", href: "/dashboard"}]
end
