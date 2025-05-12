defmodule PhxplateWeb.Live.Hooks.LayoutHooks do
  import Phoenix.Component
  alias Phxplate.Accounts.User

  def on_mount(:default, _params, _session, socket) do
    socket = assign_layout_data(socket)
    {:cont, socket}
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
    owned_companies = Phxplate.Companies.list_companies_by_owner(current_user.id)

    # Get companies where user is an employee
    employee_companies = Phxplate.Companies.list_companies_by_employee(current_user.email)

    # Combine and format all companies
    owned_company_ids = MapSet.new(owned_companies, & &1.id)

    all_companies = (owned_companies ++ employee_companies)
    |> Enum.uniq_by(&(&1.id))
    |> Enum.map(fn company ->
      %{
        id: company.id,
        name: company.name,
        plan: company.plan,
        logo: company.logo || &Lucideicons.building/1,
        is_owner: MapSet.member?(owned_company_ids, company.id)
      }
    end)

    all_nav_items = [
      %{
        title: "Basic Access",
        url: "#",
        icon: &Lucideicons.user/1,
        items: [
          %{
            title: "Basic Dashboard",
            url: "/dashboard/basic"
          },
          %{
            title: "Bookmarks",
            url: "/dashboard/basic/bookmarks"
          }
        ],
        required_role: :basic
      },
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
        ],
        required_role: :admin
      },
      %{
        title: "Super Admin",
        url: "#",
        icon: &Lucideicons.crown/1,
        items: [
          %{
            title: "Dashboard",
            url: "/dashboard/super_admin"
          },
          %{
            title: "Platform Users",
            url: "/dashboard/super_admin/users"
          },
          %{
            title: "Platform Companies",
            url: "/dashboard/super_admin/companies"
          }
        ],
        required_role: :super_admin
      }
    ]

    nav_main = Enum.filter(all_nav_items, fn item ->
      case item.required_role do
        :basic -> User.is_basic?(current_user) or User.is_admin?(current_user) or User.is_super_admin?(current_user)
        :admin -> User.is_admin?(current_user) or User.is_super_admin?(current_user)
        :super_admin -> User.is_super_admin?(current_user)
        _ -> false
      end
    end)

    current_path = case socket.private.connect_params do
      %{"request_path" => path} -> path
      _ -> "/dashboard"
    end

    user_data = if current_user.profile do
      %{
        name: current_user.profile.first_name,
        email: current_user.email,
        role: current_user.role,
        avatar: current_user.profile.avatar_url || ""
      }
    else
      %{
        name: current_user.email,
        email: current_user.email,
        role: current_user.role,
        avatar: ""
      }
    end

    layout_data = %{
      current_path: current_path,
      user: user_data,
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
      projects: all_companies
    }

    assign(socket, layout_data: layout_data)
  end
end
