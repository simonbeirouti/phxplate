defmodule PhxplateWeb.DashboardController do
  use PhxplateWeb, :controller
  alias Phxplate.Accounts.User

  def get_dashboard_data(conn) do
    current_user = conn.assigns.current_user

    # Define all possible navigation items
    all_nav_items = [
      %{
        title: "Basic Access",
        url: "#",
        icon: &Lucideicons.user/1,
        items: [
          %{
            title: "Basic Dashboard",
            url: ~p"/dashboard/basic"
          },
          %{
            title: "Basic Reports",
            url: ~p"/dashboard/basic/reports"
          },
          %{
            title: "Basic Settings",
            url: ~p"/dashboard/basic/settings"
          }
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

    # Filter navigation items based on user role
    nav_main = Enum.filter(all_nav_items, fn item ->
      case item.required_role do
        :basic -> User.is_basic?(current_user) or User.is_admin?(current_user) or User.is_super_admin?(current_user)
        :admin -> User.is_admin?(current_user) or User.is_super_admin?(current_user)
        :super_admin -> User.is_super_admin?(current_user)
        _ -> false
      end
    end)

    %{
      user: %{
        name: current_user.email,
        email: current_user.email,
        avatar: "/avatars/default.jpg"
      },
      teams: [
        %{
          name: "Acme Inc",
          logo: &Lucideicons.gallery_vertical/1,
          plan: "Enterprise"
        },
        %{
          name: "Acme Corp.",
          logo: &Lucideicons.audio_waveform/1,
          plan: "Startup"
        },
        %{
          name: "Evil Corp.",
          logo: &Lucideicons.command/1,
          plan: "Free"
        }
      ],
      navMain: nav_main,
      projects: [
        %{
          name: "Design Engineering",
          url: "#",
          icon: &Lucideicons.frame/1
        },
        %{
          name: "Sales & Marketing",
          url: "#",
          icon: &Lucideicons.presentation/1
        },
        %{
          name: "Travel",
          url: "#",
          icon: &Lucideicons.plane/1
        }
      ]
    }
  end

  def index(conn, _params) do
    render(conn, :index,
      layout: {PhxplateWeb.Components.DashboardLayout, :render},
      layout_data: get_dashboard_data(conn),
      current_path: conn.request_path
    )
  end

  def basic(conn, _params) do
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      render(conn, :basic,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
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
      render(conn, :admin,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
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
      render(conn, :admin_users,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
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
      render(conn, :admin_settings,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
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
      render(conn, :super_admin,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
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
      render(conn, :super_admin_config,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
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
      render(conn, :super_admin_audit,
        layout: {PhxplateWeb.Components.DashboardLayout, :render},
        layout_data: get_dashboard_data(conn),
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
