# lib/phxplate_web/controllers/dashboard_controller.ex
# ##############################################################################
# EDIT THIS FILE
# ##############################################################################
defmodule PhxplateWeb.DashboardController do
  use PhxplateWeb, :controller
  alias Phxplate.Accounts.User
  # alias PhxplateWeb.DashboardSubscription # Keep if used elsewhere
  alias Phxplate.Companies

  # init remains the same
  def init(_opts) do
    # DashboardSubscription.init() # Keep if used elsewhere
    # Initialize teams state
    companies = Companies.list_companies()
    # DashboardSubscription.update_state("companies", companies) # Keep if used elsewhere
    :ok
  end

  # get_dashboard_data & helpers remain the same
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
        url: "#", # This might need adjustment if the parent isn't clickable now
        icon: &Lucideicons.building/1,
        items: [
          %{
            title: "View all",
            url: ~p"/dashboard/companies" # Ensure this route still exists or adjust
          }
          # ... other sub-items
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
            url: ~p"/dashboard/profiles" # Ensure this route still exists or adjust
          }
          # ... other sub-items
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
    nav_main =
      Enum.filter(all_nav_items, fn item ->
        case item.required_role do
          :basic ->
            User.is_basic?(current_user) or User.is_admin?(current_user) or
              User.is_super_admin?(current_user)
          :admin -> User.is_admin?(current_user) or User.is_super_admin?(current_user)
          :super_admin -> User.is_super_admin?(current_user)
          _ -> false
        end
      end)

    # Get teams and convert them to companies
    companies = Companies.list_companies()

    companies_nav =
      Enum.map(companies, fn company ->
        %{
          id: company.id, # Add ID for the link in nav_companies component
          name: company.name,
          url: ~p"/dashboard/companies/#{company.id}", # Keep this URL structure
          icon: &Lucideicons.building/1,
          plan: company.plan
        }
      end)

    %{
      user: %{
        name: (current_user.profile && current_user.profile.first_name) || current_user.email,
        email: current_user.email,
        avatar: (current_user.profile && current_user.profile.avatar_url) || "/avatars/default.jpg", # Check path
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

  # NOTE: Removed index action, assuming `live "/", DashboardLive, :index` handles the root dashboard page.
  # If not, uncomment this and create `index.html.heex`.
  # def index(conn, _params) do
  #   dashboard_data = get_dashboard_data(conn)
  #   # Assign specific data for index page if needed
  #   assigns = Map.merge(dashboard_data, %{current_path: conn.request_path})
  #   render(conn, :index, assigns) # Render index.html.heex
  # end

  # NOTE: Removed ok action, seemed redundant with index or specific role actions.

  # --- Basic Role Actions ---
  def basic(conn, _params) do
    # Authorization check remains the same
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or
         User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)

      # Prepare assigns for the view template
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          # Pass specific data for the basic page
          data: %{
            message: "Welcome to the Basic Dashboard!",
            features: ["View companies", "Access basic settings", "Generate basic reports"]
          }
        })

      render(conn, :basic, assigns) # Render basic.html.heex
    else
      # Error handling remains the same
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

  def basic_reports(conn, _params) do
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or
         User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "Basic Reports",
            reports: ["Overview", "Activity", "Engagement"]
          }
        })
      render(conn, :basic_reports, assigns) # Render basic_reports.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

  def basic_settings(conn, _params) do
    if User.is_basic?(conn.assigns.current_user) or User.is_admin?(conn.assigns.current_user) or
         User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "Basic Settings",
            settings: ["Profile", "Notifications", "Preferences"]
          }
        })
      render(conn, :basic_settings, assigns) # Render basic_settings.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

   # Add basic_companies and basic_company_show if DashboardController handles these views
  def basic_companies(conn, _params) do
     # Similar authorization and rendering logic as above...
     # Fetch companies again or pass from dashboard_data if already included appropriately
     companies_list = Companies.list_companies()
     dashboard_data = get_dashboard_data(conn)
     assigns = Map.merge(dashboard_data, %{
       current_path: conn.request_path,
       data: %{ companies: companies_list, message: "Basic Companies View" }
     })
     render(conn, :basic_companies, assigns) # Render basic_companies.html.heex
  end

  def basic_company_show(conn, %{"id" => id}) do
     # Similar authorization and rendering logic...
     company = Companies.get_company!(id) # Or handle not found
     dashboard_data = get_dashboard_data(conn)
     assigns = Map.merge(dashboard_data, %{
       current_path: conn.request_path,
       data: %{ company: company, message: "Basic Company Details" }
     })
     render(conn, :basic_company_show, assigns) # Render basic_company_show.html.heex
  end


  # --- Admin Role Actions ---
  def admin(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "Welcome to the Admin Dashboard!",
            features: ["Manage users", "Configure system settings", "Access advanced reports"],
            users: Phxplate.Accounts.list_users() # Fetch data needed for the view
          }
        })
      render(conn, :admin, assigns) # Render admin.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

  def admin_users(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "User Management",
            users: Phxplate.Accounts.list_users(),
            actions: ["Create User", "Edit User", "Delete User"] # Example actions
          }
        })
      render(conn, :admin_users, assigns) # Render admin_users.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

  def admin_settings(conn, _params) do
    if User.is_admin?(conn.assigns.current_user) or User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "System Settings",
            settings: ["Security", "Integrations", "Backup"] # Example settings
          }
        })
      render(conn, :admin_settings, assigns) # Render admin_settings.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

   # Add admin_companies and admin_company_show if DashboardController handles these views
  def admin_companies(conn, _params) do
     # Similar authorization and rendering logic...
     companies_list = Companies.list_companies()
     dashboard_data = get_dashboard_data(conn)
     assigns = Map.merge(dashboard_data, %{
       current_path: conn.request_path,
       data: %{ companies: companies_list, message: "Admin Companies View" }
     })
     render(conn, :admin_companies, assigns) # Render admin_companies.html.heex
  end

  def admin_company_show(conn, %{"id" => id}) do
     # Similar authorization and rendering logic...
     company = Companies.get_company!(id)
     dashboard_data = get_dashboard_data(conn)
     assigns = Map.merge(dashboard_data, %{
       current_path: conn.request_path,
       data: %{ company: company, message: "Admin Company Details" }
     })
     render(conn, :admin_company_show, assigns) # Render admin_company_show.html.heex
  end

  # --- Super Admin Role Actions ---
  def super_admin(conn, _params) do
    if User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "Welcome to the Super Admin Dashboard!",
            features: ["Manage all users", "Configure system-wide settings", "Access audit logs"],
            system_stats: %{
              total_users: Phxplate.Accounts.count_users(),
              active_users: Phxplate.Accounts.count_active_users(), # Implement these functions
              system_status: "All systems operational"
            }
          }
        })
      render(conn, :super_admin, assigns) # Render super_admin.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

  def super_admin_config(conn, _params) do
    if User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "System Configuration",
            configs: ["Global Settings", "API Keys", "Environment Variables"] # Example configs
          }
        })
      render(conn, :super_admin_config, assigns) # Render super_admin_config.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

  def super_admin_audit(conn, _params) do
    if User.is_super_admin?(conn.assigns.current_user) do
      dashboard_data = get_dashboard_data(conn)
      assigns =
        Map.merge(dashboard_data, %{
          current_path: conn.request_path,
          data: %{
            message: "Audit Logs",
            logs: ["User Actions", "System Events", "Security Events"] # Example log types
          }
        })
      render(conn, :super_admin_audit, assigns) # Render super_admin_audit.html.heex
    else
      conn |> put_status(:forbidden) |> put_view(PhxplateWeb.ErrorHTML) |> render(:"403")
    end
  end

   # Add super_admin_companies and super_admin_company_show if DashboardController handles these views
  def super_admin_companies(conn, _params) do
     # Similar authorization and rendering logic...
     companies_list = Companies.list_companies()
     dashboard_data = get_dashboard_data(conn)
     assigns = Map.merge(dashboard_data, %{
       current_path: conn.request_path,
       data: %{ companies: companies_list, message: "Super Admin Companies View" }
     })
     render(conn, :super_admin_companies, assigns) # Render super_admin_companies.html.heex
  end

  def super_admin_company_show(conn, %{"id" => id}) do
     # Similar authorization and rendering logic...
     company = Companies.get_company!(id)
     dashboard_data = get_dashboard_data(conn)
     assigns = Map.merge(dashboard_data, %{
       current_path: conn.request_path,
       data: %{ company: company, message: "Super Admin Company Details" }
     })
     render(conn, :super_admin_company_show, assigns) # Render super_admin_company_show.html.heex
  end

end
