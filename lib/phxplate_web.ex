defmodule PhxplateWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, components, channels, and so on.

  This can be used in your application as:

      use PhxplateWeb, :controller
      use PhxplateWeb, :html

  The definitions below will be executed for every controller,
  component, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define additional modules and import
  those modules here.
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  def router do
    quote do
      use Phoenix.Router, helpers: false

      # Import common connection and controller functions to use in pipelines
      import Plug.Conn
      import Phoenix.Controller
      import Phoenix.LiveView.Router
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller,
        formats: [:html, :json],
        layouts: [html: PhxplateWeb.Layouts]

      use Gettext, backend: PhxplateWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def live_view do
    quote do
      use Phoenix.LiveView,
        layout: {PhxplateWeb.Layouts, :app}

      unquote(html_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(html_helpers())
    end
  end

  def html do
    quote do
      use Phoenix.Component

      # Import convenience functions from controllers
      import Phoenix.Controller,
        only: [get_csrf_token: 0, view_module: 1, view_template: 1]

      # Include general helpers for rendering HTML
      unquote(html_helpers())
    end
  end

  defp html_helpers do
    quote do
      # Translation
      use Gettext, backend: PhxplateWeb.Gettext

      # HTML escaping functionality
      import Phoenix.HTML
      # Core UI components
      import PhxplateWeb.CoreComponents

      # Custom UI components
      import PhxplateWeb.Components.UI.Accordion
      import PhxplateWeb.Components.UI.Breadcrumb
      import PhxplateWeb.Components.UI.Collapsible
      import PhxplateWeb.Components.UI.Drawer
      import PhxplateWeb.Components.UI.Dialog
      import PhxplateWeb.Components.UI.DialogDrawerWrapper
      import PhxplateWeb.Components.UI.DropdownMenu
      import PhxplateWeb.Components.UI.Helpers
      # import PhxplateWeb.Components.UI.Input
      import PhxplateWeb.Components.UI.Pagination
      import PhxplateWeb.Components.UI.Menu
      import PhxplateWeb.Components.UI.Select
      import PhxplateWeb.Components.UI.Separator
      import PhxplateWeb.Components.UI.Sheet
      import PhxplateWeb.Components.UI.Sidebar
      import PhxplateWeb.Components.UI.Skeleton
      import PhxplateWeb.Components.UI.Slider
      import PhxplateWeb.Components.UI.Switch
      import PhxplateWeb.Components.UI.Table
      import PhxplateWeb.Components.UI.Tooltip

      # Salad UI components
      import SaladUI.{
        Alert,
        Avatar,
        Badge,
        Button,
        Card,
        Checkbox,
        Form,
        HoverCard,
        Icon,
        Popover,
        Progress,
        RadioGroup,
        ScrollArea,
        Skeleton,
        Tabs,
        Toggle,
        ToggleGroup
      }

      # Shortcut for generating JS commands
      alias Phoenix.LiveView.JS

      # Routes generation with the ~p sigil
      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: PhxplateWeb.Endpoint,
        router: PhxplateWeb.Router,
        statics: PhxplateWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/live_view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
