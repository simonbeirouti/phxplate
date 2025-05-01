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
    companies = Phxplate.Companies.list_companies()

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
        title: "Admin Access",
        url: "#",
        icon: &Lucideicons.shield/1,
        items: [
          %{
            title: "Admin Dashboard",
            url: "/dashboard/admin"
          },
          %{
            title: "User Admin Page",
            url: "/dashboard/admin/adminpage"
          },
          %{
            title: "User Admin Page 2",
            url: "/dashboard/admin/adminpage2"
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
            url: "/dashboard/super_admin"
          },
          %{
            title: "Super Admin Page",
            url: "/dashboard/super_admin/super_adminpage"
          },
          %{
            title: "Super Admin Page 2",
            url: "/dashboard/super_admin/super_adminpage2"
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

    layout_data = %{
      current_path: current_path,
      user: %{
        name: current_user.profile.first_name,
        email: current_user.email,
        role: current_user.role,
        avatar: current_user.profile.avatar_url
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
      projects: companies
    }

    assign(socket, layout_data: layout_data)
  end
end
