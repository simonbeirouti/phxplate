defmodule PhxplateWeb.Components.DashboardLayout do
  @moduledoc false
  use PhxplateWeb, :html
  use SaladUI

  import Lucideicons, except: [import: 1, quote: 1, menu: 1, link: 1]

  def render(assigns) do
    ~H"""
    <.sidebar_provider>
      <.sidebar_main data={@layout_data}></.sidebar_main>
      <.sidebar_inset>
        <header class="flex h-16 shrink-0 items-center gap-2 border-b px-4">
          <button
            type="button"
            id="mobile-menu-button"
            class="md:hidden inline-flex items-center justify-center rounded-md p-2 text-gray-700 hover:bg-gray-100 hover:text-gray-900"
            phx-hook="MobileMenu"
          >
            <span class="sr-only">Open main menu</span>
            <Lucideicons.menu class="h-6 w-6" id="menu-icon" />
            <Lucideicons.x class="h-6 w-6 hidden" id="close-icon" />
          </button>

          <.sidebar_trigger target="main-sidebar" class="ml-1 hidden md:block">
            <Lucideicons.panel_left class="w-4 h-4" />
          </.sidebar_trigger>

          <.separator orientation="vertical" class="mr-2 h-4" />
          <.breadcrumb>
            <.breadcrumb_list>
              <%= for {item, idx} <- Enum.with_index(dashboard_breadcrumbs(@current_path || "/dashboard")) do %>
                <.breadcrumb_item class={if idx == 0, do: "hidden md:block", else: nil}>
                  <.breadcrumb_link href={item.href}>
                    {item.label}
                  </.breadcrumb_link>
                </.breadcrumb_item>
                <.breadcrumb_separator
                  :if={idx < length(dashboard_breadcrumbs(@current_path || "/dashboard")) - 1}
                  class="hidden md:block"
                />
              <% end %>
            </.breadcrumb_list>
          </.breadcrumb>
        </header>

        <div id="mobile-menu" class="hidden md:hidden">
          <div class="space-y-1 px-2 pb-3 pt-2">
            <.mobile_nav_main items={@layout_data.navMain} />
            <.mobile_nav_projects projects={@layout_data.projects} />
            <.mobile_nav_user user={@layout_data.user} />
          </div>
        </div>

        <div class="p-4">
          {@inner_content}
        </div>
      </.sidebar_inset>
    </.sidebar_provider>
    """
  end

  def sidebar_main(assigns) do
    ~H"""
    <.sidebar collapsible="icon" id="main-sidebar">
      <.sidebar_header>
        <.team_switcher user={@data.user} teams={@data.teams} />
      </.sidebar_header>
      <.sidebar_content>
        <.nav_main items={@data.navMain} />
        <.nav_projects projects={@data.projects} />
      </.sidebar_content>
      <.sidebar_footer>
        <.nav_user user={@data.user} />
      </.sidebar_footer>
      <.sidebar_rail />
    </.sidebar>
    """
  end

  def team_switcher(assigns) do
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
            <div class="flex aspect-square size-8 items-center justify-center rounded-lg bg-sidebar-primary text-sidebar-primary-foreground -ml-2">
              <Lucideicons.command class="size-4" />
            </div>
            <div class="grid flex-1 text-left text-sm leading-tight ml-2">
              <span class="truncate font-semibold">
                {@user.name}
              </span>
              <span class="truncate text-xs">
                {@user.role}
              </span>
            </div>
            <%!-- <Lucideicons.chevrons_up_down class="ml-auto" /> --%>
          </.as_child>
          <%!-- <.dropdown_menu_content
            class="w-[--radix-dropdown-menu-trigger-width] min-w-56 rounded-lg"
            align="start"
            side="right"
          >
            <.menu>
              <.menu_label class="text-xs text-muted-foreground">
                Teams
              </.menu_label>

              <.menu_item :for={{team, index} <- Enum.with_index(@teams)} class="gap-2 p-2">
                <div class="flex size-6 items-center justify-center rounded-sm border">
                  <.dynamic tag={team.logo} class="size-4 shrink-0" />
                </div>
                {team.name}
                <.dropdown_menu_shortcut>
                  ⌘{index + 1}
                </.dropdown_menu_shortcut>
              </.menu_item>

              <.menu_separator></.menu_separator>
              <.menu_item class="gap-2 p-2">
                <div class="flex size-6 items-center justify-center rounded-md border bg-background">
                  <.plus class="size-4" />
                </div>
                <div class="font-medium text-muted-foreground">
                  Add team
                </div>
              </.menu_item>
            </.menu>
          </.dropdown_menu_content> --%>
        </.dropdown_menu>
      </.sidebar_menu_item>
    </.sidebar_menu>
    """
  end

  def nav_main(assigns) do
    ~H"""
    <.sidebar_group>
      <.sidebar_group_label>
        Platform
      </.sidebar_group_label>
      <.sidebar_menu :for={item <- @items}>
        <%!-- <.collapsible
          :for={item <- @items}
          id={id(item.title)}
          open={item[:is_active]}
          class="group/collapsible block"
        > --%>
          <.sidebar_menu_item>
            <.as_child
              tag={&collapsible_trigger/1}
              child={&sidebar_menu_button/1}
              tooltip={item.title}
            >
              <.dynamic :if={not is_nil(item.icon)} tag={item.icon} />

              <span>
                {item.title}
              </span>
              <%!-- <Lucideicons.chevron_right class="ml-auto transition-transform duration-200 group-data-[state=open]/collapsible:rotate-90" /> --%>
            </.as_child>
            <%!-- <.collapsible_content> --%>
              <.sidebar_menu_sub>
                <.sidebar_menu_sub_item :for={sub_item <- item.items}>
                  <.as_child tag={&sidebar_menu_sub_button/1} child="a" href={sub_item.url}>
                    <span>
                      {sub_item.title}
                    </span>
                  </.as_child>
                </.sidebar_menu_sub_item>
              </.sidebar_menu_sub>
            <%!-- </.collapsible_content> --%>
          </.sidebar_menu_item>
        <%!-- </.collapsible> --%>
      </.sidebar_menu>
    </.sidebar_group>
    """
  end

  def nav_projects(assigns) do
    ~H"""
    <.sidebar_group>
      <.sidebar_group_label>
        Companies
      </.sidebar_group_label>
      <.sidebar_menu>
        <.sidebar_menu_item :for={project <- @projects}>
          <.sidebar_menu_button class="flex items-center gap-2">
            <.dynamic tag={project.icon} />
            <a href={project.url}>
              {project.name}
            </a>
          </.sidebar_menu_button>
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
                CN
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
            side="top"
            align="start"
          >
            <.menu>
              <dropdownmenugroup>
                <.menu_item>
                  <.sparkles class="w-4 h-4 mr-2" /> Upgrade to Pro
                </.menu_item>
              </dropdownmenugroup>
              <.menu_separator></.menu_separator>
              <.link href={~p"/users/log_out"} method="delete">
                <.menu_item>
                  <.log_out class="w-4 h-4 mr-2" /> Log out
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
    <div class="space-y-1">
      <div class="px-3 py-2 text-sm font-medium text-gray-500">Projects</div>
      <%= for item <- @projects do %>
        <.link
          href={item.url}
          class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
        >
          <.dynamic tag={item.icon} class="mr-2 h-4 w-4" />
          <span>{item.name}</span>
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
        href={~p"/users/log_out"}
        method="delete"
        class="flex items-center rounded-md px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-100"
      >
        <Lucideicons.log_out class="mr-2 h-4 w-4" />
        <span>Log out</span>
      </.link>
    </div>
    """
  end

  defp dashboard_breadcrumbs("/dashboard" <> rest) do
    segments =
      rest
      |> String.trim_leading("/")
      |> String.split("/", trim: true)

    base = [%{label: "Dashboard", href: "/dashboard"}]

    Enum.reduce(segments, {base, "/dashboard"}, fn seg, {acc, path} ->
      next_path = path <> "/" <> seg
      label = seg |> String.replace("_", " ") |> String.capitalize()
      {acc ++ [%{label: label, href: next_path}], next_path}
    end)
    |> elem(0)
  end

  defp dashboard_breadcrumbs(_), do: [%{label: "Dashboard", href: "/dashboard"}]
end
