defmodule PhxplateWeb.Live.Hooks.LayoutHooks do
  @moduledoc """
  LiveView hooks for managing layout data and subscriptions.

  This module provides hooks that are applied to LiveViews to manage layout-related data
  and PubSub subscriptions. It handles the assignment of layout data, including user details,
  navigation menus, companies, and bookmarks, and subscribes to relevant PubSub topics
  for real-time updates.
  """
  import Phoenix.Component
  import Phoenix.LiveView, only: [connected?: 1]
  alias Phxplate.Accounts.User
  alias Phxplate.PubSub.DataSync
  alias Phxplate.{Companies, Bookmarks}

  @doc """
  Mounts default layout data and sets up PubSub subscriptions.

  This hook runs when LiveViews are mounted. It subscribes to PubSub topics for
  company, employee, invitation, and bookmark updates, and assigns initial layout
  data to the socket.
  """
  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      current_user = socket.assigns.current_user
      # Subscribe to all company updates
      DataSync.subscribe("companies", "all")
      # Subscribe to user-specific employee updates
      DataSync.subscribe("user_invitations", current_user.email)
      # Subscribe to employee updates
      DataSync.subscribe("employees", "all")
      # Subscribe to user-specific bookmark updates
      DataSync.subscribe("bookmarks", current_user.id)
    end

    socket = assign_layout_data(socket)
    {:cont, socket}
  end

  def handle_info({:created, %{type: :employee, employee: employee}}, socket) do
    current_user = socket.assigns.current_user

    if employee.email == current_user.email do
      {:noreply, assign_layout_data(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:created, %{type: :company, company: company}}, socket) do
    current_user = socket.assigns.current_user

    if company.owner_id == current_user.id do
      {:noreply, assign_layout_data(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:updated, %{type: :company, company: company}}, socket) do
    current_user = socket.assigns.current_user

    if company.owner_id == current_user.id ||
         Enum.any?(company.employees, &(&1.email == current_user.email)) do
      {:noreply, assign_layout_data(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :company, id: _company_id}}, socket) do
    {:noreply, assign_layout_data(socket)}
  end

  def handle_info({:created, %{type: :bookmark, bookmark: bookmark}}, socket) do
    current_user = socket.assigns.current_user

    if bookmark.user_id == current_user.id do
      {:noreply, assign_layout_data(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:deleted, %{type: :bookmark, id: _bookmark_id}}, socket) do
    {:noreply, assign_layout_data(socket)}
  end

  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:cont, socket}
  end

  defp assign_layout_data(socket) do
    current_user = socket.assigns.current_user
    current_user = Phxplate.Repo.preload(current_user, [:profile])

    # Get companies owned by user
    owned_companies = Companies.list_companies_by_owner(current_user.id)

    # Get companies where user is an employee
    employee_companies = Companies.list_companies_by_employee(current_user.email)

    # Get bookmarked companies
    bookmarked_companies =
      Bookmarks.list_user_bookmarks(current_user.id)
      |> Enum.map(& &1.company)

    # Combine and format all companies
    owned_company_ids = MapSet.new(owned_companies, & &1.id)
    employee_company_ids = MapSet.new(employee_companies, & &1.id)

    format_company = fn company ->
      %{
        id: company.id,
        name: company.name,
        logo: company.logo || "",
        is_owner: MapSet.member?(owned_company_ids, company.id),
        is_employee: MapSet.member?(employee_company_ids, company.id)
      }
    end

    all_companies =
      (owned_companies ++ employee_companies)
      |> Enum.uniq_by(& &1.id)
      |> Enum.map(format_company)

    bookmarked =
      bookmarked_companies
      |> Enum.map(format_company)

    # Define navigation items by access level
    user_access_items = [
      %{
        title: "Personal Dashboard",
        url: "#",
        icon: &Lucideicons.user/1,
        items: [
          %{
            title: "Dashboard",
            url: "/dashboard/basic"
          },
          %{
            title: "Bookmarks",
            url: "/dashboard/basic/bookmarks"
          },
          %{
            title: "Invites",
            url: "/dashboard/invites"
          },
          %{
            title: "Account",
            url: "/dashboard/account"
          }
        ]
      }
    ]

    company_access_items = [
      %{
        title: "Company Management",
        url: "#",
        icon: &Lucideicons.briefcase_business/1,
        items: [
          %{
            title: "Dashboard",
            url: "/dashboard/admin"
          },
          %{
            title: "Companies",
            url: "/dashboard/admin/companies"
          }
        ]
      }
    ]

    super_admin_items = [
      %{
        title: "Platform Management",
        url: "#",
        icon: &Lucideicons.crown/1,
        items: [
          %{
            title: "Dashboard",
            url: "/dashboard/super_admin"
          },
          %{
            title: "Subscriptions",
            url: "/dashboard/super_admin/subscriptions"
          },
          %{
            title: "Blogs",
            url: "/dashboard/super_admin/blogs"
          },
          %{
            title: "Companies",
            url: "/dashboard/super_admin/companies"
          },
          %{
            title: "Settings",
            url: "/dashboard/super_admin/platform-settings"
          }
        ]
      },
      %{
        title: "Customer Engagement",
        url: "#",
        icon: &Lucideicons.users/1,
        items: [
          %{
            title: "Support Chat",
            url: "/dashboard/super_admin/chat"
          },
          %{
            title: "Feature/Feedback",
            url: "/dashboard/super_admin/feature-feedbacks"
          },
          %{
            title: "Users",
            url: "/dashboard/super_admin/users"
          }
        ]
      },
      %{
        title: "AI Management",
        url: "#",
        icon: &Lucideicons.bot/1,
        items: [
          %{
            title: "AI Chat",
            url: "/dashboard/super_admin/ai-chat"
          },
          %{
            title: "AI Prompts",
            url: "/dashboard/super_admin/ai-prompts"
          },
          %{
            title: "AI Evaluations",
            url: "/dashboard/super_admin/ai-evals"
          },
          %{
            title: "AI Eval Results",
            url: "/dashboard/super_admin/ai-eval-results"
          },
          %{
            title: "AI Results",
            url: "/dashboard/super_admin/ai-results"
          }
        ]
      }
    ]

    # Build navigation based on user role
    nav_groups = []

    # Add User Access for all users
    nav_groups =
      if User.is_basic?(current_user) or User.is_admin?(current_user) or
           User.is_super_admin?(current_user) do
        nav_groups ++ [%{label: "User Access", items: user_access_items}]
      else
        nav_groups
      end

    # Add Company Access for admin and super admin
    nav_groups =
      if User.is_admin?(current_user) or User.is_super_admin?(current_user) do
        nav_groups ++ [%{label: "Company Access", items: company_access_items}]
      else
        nav_groups
      end

    # Add Super Admin Access for super admin only
    nav_groups =
      if User.is_super_admin?(current_user) do
        nav_groups ++ [%{label: "Super Admin Access", items: super_admin_items}]
      else
        nav_groups
      end

    current_path =
      case socket.private.connect_params do
        %{"request_path" => path} -> path
        _ -> "/dashboard"
      end

    user_data =
      if current_user.profile do
        %{
          id: current_user.id,
          name: current_user.profile.first_name,
          email: current_user.email,
          role: current_user.role,
          avatar: current_user.profile.avatar_url || ""
        }
      else
        %{
          id: current_user.id,
          name: current_user.email,
          email: current_user.email,
          role: current_user.role,
          avatar: ""
        }
      end

    layout_data = %{
      current_path: current_path,
      user: user_data,
      navGroups: nav_groups,
      companies: all_companies,
      bookmarked: bookmarked
    }

    assign(socket, layout_data: layout_data)
  end
end
