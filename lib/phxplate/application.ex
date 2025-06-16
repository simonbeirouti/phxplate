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

    # Run seeding after application start if needed
    initialize_database_if_needed()

    result
  end

  # Check if seeding is needed and run it
  defp initialize_database_if_needed do
    if System.get_env("SEED_DATABASE") == "true" do
      Logger.info("SEED_DATABASE flag detected, scheduling database seeding...")

      # Run as a supervised task to not block application startup
      Task.Supervisor.start_child(Phxplate.TaskSupervisor, fn ->
        # Allow the app to fully start first
        Process.sleep(5000)

        alias Phxplate.Repo
        alias Phxplate.Accounts.{User, Profile}
        alias Phxplate.Subscriptions.{Plan}
        require Ecto.Query

        # Check if seeding is necessary
        if Repo.exists?(Ecto.Query.from(u in User, where: u.role == :super_admin)) or
           Repo.exists?(Ecto.Query.from(p in Plan)) do
          Logger.info("Seeding skipped - Super admin or plans already exist")
        else
          Logger.info("Starting database seeding...")

          # Seed all the data here (moved from release.ex)
          # [Your seeding logic goes here]
          # Example:
          create_plans_and_admin()

          # Unset the flag after successful seeding
          System.delete_env("SEED_DATABASE")
          Logger.info("Database seeding completed successfully!")
        end
      end)
    end
  end

  # Implementation of the actual seeding logic
  defp create_plans_and_admin do
    alias Phxplate.Repo
    alias Phxplate.Accounts.{User, Profile}
    alias Phxplate.Subscriptions.{Plan}

    # Plan creation logic from your release.ex
    plan_data = [
      %{name: "Small Plan", description: "For small teams", tier: "small", monthly_amount: 1500,
        features: %{"projects" => 5, "storage" => "5GB", "support" => "Email"}},
      %{name: "Medium Plan", description: "For medium teams", tier: "medium", monthly_amount: 3000,
        features: %{"projects" => 10, "storage" => "10GB", "support" => "Priority Email"}},
      %{name: "Large Plan", description: "For enterprise teams", tier: "large", monthly_amount: 5000,
        features: %{"projects" => "Unlimited", "storage" => "20GB", "support" => "24/7 Phone & Email"}}
    ]

    # Create the plans in Stripe and your database
    created_plans = Enum.map(plan_data, fn plan ->
      # Create Stripe product
      {:ok, product} = Stripe.Product.create(%{
        name: plan.name,
        description: plan.description,
        metadata: %{tier: plan.tier}
      })

      # Create monthly price
      {:ok, monthly_price} = Stripe.Price.create(%{
        unit_amount: plan.monthly_amount,
        currency: "usd",
        product: product.id,
        recurring: %{interval: "month"}
      })

      # Create yearly price
      {:ok, yearly_price} = Stripe.Price.create(%{
        unit_amount: plan.monthly_amount * 10,
        currency: "usd",
        product: product.id,
        recurring: %{interval: "year"}
      })

      # Store monthly plan in database
      {:ok, monthly_db_plan} = Repo.insert(%Plan{
        name: plan.name,
        description: plan.description,
        unit_amount: plan.monthly_amount,
        currency: "usd",
        interval: "month",
        metadata: %{tier: plan.tier},
        features: plan.features,
        stripe_price_id: monthly_price.id,
        stripe_product_id: product.id
      })

      # Store yearly plan in database
      {:ok, yearly_db_plan} = Repo.insert(%Plan{
        name: plan.name,
        description: plan.description,
        unit_amount: plan.monthly_amount * 10,
        currency: "usd",
        interval: "year",
        metadata: %{tier: plan.tier},
        features: plan.features,
        stripe_price_id: yearly_price.id,
        stripe_product_id: product.id
      })

      %{
        monthly: %{stripe: monthly_price, db: monthly_db_plan},
        yearly: %{stripe: yearly_price, db: yearly_db_plan},
        product: product
      }
    end)

    # Store price IDs in application config
    Application.put_env(:phxplate, :subscriptions, %{
      tiers:
        created_plans
        |> Enum.map(fn %{monthly: monthly, product: product} ->
          {String.to_atom(product.metadata["tier"]), %{price_id: monthly.stripe.id}}
        end)
        |> Enum.into(%{})
    })

    # Create super admin user
    super_admin_email = "admin@example.com"
    super_admin_password = "changeme1234"

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

    Logger.info("Created super admin user: #{super_admin_email}")
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PhxplateWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
