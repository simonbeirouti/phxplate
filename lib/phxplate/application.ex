defmodule Phxplate.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      PhxplateWeb.Telemetry,
      Phxplate.Repo,
      {DNSCluster, query: Application.get_env(:phxplate, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Phxplate.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Phxplate.Finch},
      # Start a worker by calling: Phxplate.Worker.start_link(arg)
      # {Phxplate.Worker, arg},
      # AI Evaluation Queue - add before the endpoint
      {Phxplate.AI.EvaluationQueue, []},
      # Start to serve requests, typically the last entry
      PhxplateWeb.Endpoint,
      # For SaladUI
      TwMerge.Cache,
      # Add a Task supervisor for potentially long-running tasks
      {Task.Supervisor, name: Phxplate.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Phxplate.Supervisor]
    result = Supervisor.start_link(children, opts)

    # Initialize database with essential data
    initialize_database_if_needed()

    result
  end

  # Initialize database with essential data (super admin)
  defp initialize_database_if_needed do
    # Always ensure we have a super admin user for basic access
    ensure_super_admin_exists()
  end

  # Ensure super admin exists for basic access
  defp ensure_super_admin_exists do
    Task.Supervisor.start_child(Phxplate.TaskSupervisor, fn ->
      # Allow the app to fully start first
      Process.sleep(3000)

      alias Phxplate.Repo
      alias Phxplate.Accounts.{User, Profile}
      require Ecto.Query

      # Check if super admin already exists
      if Repo.exists?(Ecto.Query.from(u in User, where: u.role == :super_admin)) do
        Logger.info("Super admin already exists")
      else
        Logger.info("Creating super admin user...")

        try do
          # Create super admin user
          super_admin_email = "admin@phxplate.com"
          super_admin_password = "password1234"

          {:ok, super_admin} =
            %User{}
            |> User.registration_changeset(%{
              email: super_admin_email,
              password: super_admin_password,
              role: :super_admin,
              onboarding_completed: true
            })
            |> Repo.insert()

          # Create profile for super admin
          Repo.insert!(%Profile{
            first_name: "Super",
            last_name: "Admin",
            bio: "Platform administrator",
            avatar_url: nil,
            phone: nil,
            location: nil,
            website: nil,
            social_links: %{},
            user_id: super_admin.id
          })

          Logger.info("✅ Super admin created successfully!")
          Logger.info("📧 Email: #{super_admin_email}")
          Logger.info("🔑 Password: #{super_admin_password}")
        rescue
          error ->
            Logger.error("Failed to create super admin: #{inspect(error)}")
        end
      end
    end)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxplateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
