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
    companies = Phxplate.Companies.list_companies_by_owner(current_user.id)

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
            title: "Basic Page",
            url: "/dashboard/basic/basicpage"
          },
          %{
            title: "Basic Page 2",
            url: "/dashboard/basic/basicpage2"
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
            title: "Company Access",
            url: "/dashboard/admin/company"
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
      projects: companies
    }

    assign(socket, layout_data: layout_data)
  end
end
