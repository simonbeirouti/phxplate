defmodule PhxplateWeb.DashboardController do
  use PhxplateWeb, :controller
  alias Phxplate.Accounts.User
  alias PhxplateWeb.DashboardSubscription
  alias Phxplate.Companies

  def init(_opts) do
    DashboardSubscription.init()
    # Initialize teams state
    companies = Companies.list_companies()
    # DashboardSubscription.update_state("companies", companies)
    :ok
  end

  def get_dashboard_data(%Plug.Conn{} = conn) do
    get_dashboard_data_for_user(conn.assigns.current_user)
  end

  def get_dashboard_data(%Phoenix.LiveView.Socket{} = socket) do
    get_dashboard_data_for_user(socket.assigns.current_user)
  end

  defp get_dashboard_data_for_user(current_user) do

    # Get available roles based on current user's role
    available_roles = get_available_roles(current_user)

    # Define all possible navigation items
    all_nav_items = [
      %{
        title: "Companies",
        url: "#",
        icon: &Lucideicons.building/1,
        items: [
          %{
            title: "View all",
            url: ~p"/dashboard/companies"
          },
          # %{
          #   title: "Basic Reports",
          #   url: ~p"/dashboard/companies/:id"
          # },
        ],
        required_role: :basic
      },
      %{
        title: "Community",
        url: "#",
        icon: &Lucideicons.user/1,
        items: [
          %{
            title: "View all",
            url: ~p"/dashboard/profiles"
          },
          # %{
          #   title: "Basic Reports",
          #   url: ~p"/dashboard/companies/:id"
          # },
        ],
        required_role: :basic
      },
      %{
        title: "Admin Access",
        url: "#",
        icon: &Lucideicons.shield/1,
        items: [
          %{
            title: "Admin Dashboard",
            url: ~p"/dashboard/admin"
          },
          %{
            title: "User Management",
            url: ~p"/dashboard/admin/users"
          },
          %{
            title: "System Settings",
            url: ~p"/dashboard/admin/settings"
          }
        ],
        required_role: :admin
      },
      %{
        title: "Super Admin",
        url: "#",
        icon: &Lucideicons.crown/1,
        items: [
          %{
            title: "Super Admin Dashboard",
            url: ~p"/dashboard/super_admin"
          },
          %{
            title: "System Configuration",
            url: ~p"/dashboard/super_admin/config"
          },
          %{
            title: "Audit Logs",
            url: ~p"/dashboard/super_admin/audit"
          }
        ],
        required_role: :super_admin
      }
    ]

    # Filter navigation items based on current user's role
    nav_main = Enum.filter(all_nav_items, fn item ->
      case item.required_role do
        :basic -> User.is_basic?(current_user) or User.is_admin?(current_user) or User.is_super_admin?(current_user)
        :admin -> User.is_admin?(current_user) or User.is_super_admin?(current_user)
        :super_admin -> User.is_super_admin?(current_user)
        _ -> false
      end
    end)

    # Get teams and convert them to companies
    companies = Companies.list_companies()
    companies_nav = Enum.map(companies, fn company ->
      %{
        name: company.name,
        url: ~p"/dashboard/companies/#{company.id}",
        icon: &Lucideicons.building/1,
        plan: company.plan
      }
    end)

    %{
      user: %{
        name: (current_user.profile && current_user.profile.first_name) || current_user.email,
        email: current_user.email,
        avatar: (current_user.profile && current_user.profile.avatar_url) || "/avatars/default.jpg",
        role: current_user.role,
        available_roles: available_roles
      },
      navMain: nav_main,
      companies: companies_nav
    }
  end

  defp get_available_roles(user) do
    cond do
      User.is_super_admin?(user) -> [:basic, :admin, :super_admin]
      User.is_admin?(user) -> [:basic, :admin]
      true -> [:basic]
    end
  end

  def index(conn, _params) do
    dashboard_data = get_dashboard_data(conn)

    conn
    |> assign(:navMain, dashboard_data.navMain)
    |> assign(:companies, dashboard_data.companies)
    |> assign(:user, dashboard_data.user)
    |> assign(:current_path, conn.request_path)
    |> put_root_layout({PhxplateWeb.Layouts, :root})
    |> put_layout({PhxplateWeb.Layouts, :dashboard})
    |> render(:index)
  end

  def ok(conn, _params) do
    dashboard_data = get_dashboard_data(conn)

    conn
    |> assign(:navMain, dashboard_data.navMain)
    |> assign(:companies, dashboard_data.companies)
    |> assign(:user, dashboard_data.user)
    |> assign(:current_path, conn.request_path)
    |> put_root_layout({PhxplateWeb.Layouts, :root})
    |> put_layout({PhxplateWeb.Layouts, :dashboard})
    |> render(:index)
  end

  def basic(conn, _params) do
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)

      conn
      |> assign(:navMain, dashboard_data.navMain)
      |> assign(:companies, dashboard_data.companies)
      |> assign(:user, dashboard_data.user)
      |> assign(:current_path, conn.request_path)
      |> put_root_layout({PhxplateWeb.Layouts, :root})
      |> put_layout({PhxplateWeb.Layouts, :dashboard})
      |> render(:admin,
        navMain: dashboard_data.navMain,
        companies: dashboard_data.companies,
        user: dashboard_data.user,
        data: %{
          message: "Welcome to the Basic Dashboard!",
          features: ["View basic reports", "Access limited settings"]
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def basic_reports(conn, _params) do
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      render(conn, :basic_reports,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
        data: %{
          message: "Basic Reports",
          reports: ["Daily Summary", "Weekly Overview", "Monthly Analytics"]
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def basic_settings(conn, _params) do
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      render(conn, :basic_settings,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
        data: %{
          message: "Basic Settings",
          settings: ["Profile", "Notifications", "Preferences"]
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def admin(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      render(conn, :admin,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        navMain: dashboard_data.navMain,
        companies: dashboard_data.companies,
        user: dashboard_data.user,
        data: %{
          message: "Welcome to the Admin Dashboard!",
          features: ["Manage users", "View analytics", "Configure system settings"],
          users: Phxplate.Accounts.list_users()
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def admin_users(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      conn
      |> put_root_layout({PhxplateWeb.Layouts, :root})
      |> put_layout({PhxplateWeb.Layouts, :dashboard})
      |> render(:admin_users,
        navMain: dashboard_data.navMain,
        companies: dashboard_data.companies,
        user: dashboard_data.user,
        data: %{
          message: "User Management",
          users: Phxplate.Accounts.list_users(),
          actions: ["Create User", "Edit User", "Delete User"]
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def admin_settings(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      conn
      |> put_root_layout({PhxplateWeb.Layouts, :root})
      |> put_layout({PhxplateWeb.Layouts, :dashboard})
      |> render(:admin_settings,
        navMain: dashboard_data.navMain,
        companies: dashboard_data.companies,
        user: dashboard_data.user,
        data: %{
          message: "System Settings",
          settings: ["Security", "Integrations", "Backup"]
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def super_admin(conn, _params) do
    if User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      conn
      |> put_root_layout({PhxplateWeb.Layouts, :root})
      |> put_layout({PhxplateWeb.Layouts, :dashboard})
      |> render(:super_admin,
        navMain: dashboard_data.navMain,
        companies: dashboard_data.companies,
        user: dashboard_data.user,
        data: %{
          message: "Welcome to the Super Admin Dashboard!",
          features: ["Manage all users", "Configure system-wide settings", "Access audit logs"],
          system_stats: %{
            total_users: Phxplate.Accounts.count_users(),
            active_users: Phxplate.Accounts.count_active_users(),
            system_status: "All systems operational"
          }
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def super_admin_config(conn, _params) do
    if User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      conn
      |> put_root_layout({PhxplateWeb.Layouts, :root})
      |> put_layout({PhxplateWeb.Layouts, :dashboard})
      |> render(:super_admin_config,
        navMain: dashboard_data.navMain,
        companies: dashboard_data.companies,
        user: dashboard_data.user,
        data: %{
          message: "System Configuration",
          configs: ["Global Settings", "API Keys", "Environment Variables"]
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end

  def super_admin_audit(conn, _params) do
    if User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      conn
      |> put_root_layout({PhxplateWeb.Layouts, :root})
      |> put_layout({PhxplateWeb.Layouts, :dashboard})
      |> render(:super_admin_audit,
        navMain: dashboard_data.navMain,
        companies: dashboard_data.companies,
        user: dashboard_data.user,
        data: %{
          message: "Audit Logs",
          logs: ["User Actions", "System Events", "Security Events"]
        },
        current_path: conn.request_path
      )
    else
      conn
      |> put_status(:forbidden)
      |> put_view(PhxplateWeb.ErrorHTML)
      |> render(:"403")
    end
  end
end
