defmodule PhxplateWeb.DashboardController do
  use PhxplateWeb, :controller
  alias Phxplate.Accounts.User

  def get_dashboard_data(conn) do
    %{
      user: %{
        name: conn.assigns.current_user.email,
        email: conn.assigns.current_user.email,
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
      navMain: [
        %{
          title: "Playground",
          url: "#",
          icon: &Lucideicons.square_terminal/1,
          is_active: true,
          items: [
            %{
              title: "History",
              url: "#"
            },
            %{
              title: "Starred",
              url: "#"
            },
            %{
              title: "Settings",
              url: "#"
            }
          ]
        },
        %{
          title: "Models",
          url: "#",
          icon: &Lucideicons.bot/1,
          items: [
            %{
              title: "Genesis",
              url: "#"
            },
            %{
              title: "Explorer",
              url: "#"
            },
            %{
              title: "Quantum",
              url: "#"
            }
          ]
        },
        %{
          title: "Documentation",
          url: "#",
          icon: &Lucideicons.book_open/1,
          items: [
            %{
              title: "Introduction",
              url: "#"
            },
            %{
              title: "Get Started",
              url: "#"
            },
            %{
              title: "Tutorials",
              url: "#"
            },
            %{
              title: "Changelog",
              url: "#"
            }
          ]
        },
        %{
          title: "Settings",
          url: "#",
          icon: &Lucideicons.settings/1,
          items: [
            %{
              title: "General",
              url: "#"
            },
            %{
              title: "Team",
              url: "#"
            },
            %{
              title: "Billing",
              url: "#"
            },
            %{
              title: "Limits",
              url: "#"
            }
          ]
        }
      ],
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
end
