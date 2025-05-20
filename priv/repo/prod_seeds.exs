# Production seed file for creating super admin and plans
# Run with: mix run priv/repo/prod_seeds.exs

import Ecto.Query
alias Phxplate.Repo
alias Phxplate.Accounts.{User, Profile}
alias Phxplate.Subscriptions.{Plan}

# Production seed script for initializing the application with default data.
#
# This script:
# 1. Creates subscription plans in Stripe and the local database
# 2. Creates a super admin user with a profile
# 3. Sets up application configuration for subscriptions
#
# It will exit early if a super admin or plans already exist to prevent duplicate data.

# Check if super admin or plans already exist
if Repo.exists?(from u in User, where: u.role == :super_admin) or Repo.exists?(from p in Plan) do
  IO.puts("""
  Production seed already run!
  Either a super admin or plans already exist in the database.
  If you need to reset the database, run:
  mix ecto.reset
  """)
  System.halt(0)
end

# Create plans
plan_data = [
  %{
    name: "Small Plan",
    description: "For small teams",
    tier: "small",
    monthly_amount: 1500,
    features: %{
      "projects" => 5,
      "storage" => "5GB",
      "support" => "Email"
    }
  },
  %{
    name: "Medium Plan",
    description: "For medium teams",
    tier: "medium",
    monthly_amount: 3000,
    features: %{
      "projects" => 10,
      "storage" => "10GB",
      "support" => "Priority Email"
    }
  },
  %{
    name: "Large Plan",
    description: "For enterprise teams",
    tier: "large",
    monthly_amount: 5000,
    features: %{
      "projects" => "Unlimited",
      "storage" => "20GB",
      "support" => "24/7 Phone & Email"
    }
  }
]

# Create products and prices in Stripe, then store in our database
# Each plan creates both monthly and yearly billing options
created_plans =
  Enum.map(plan_data, fn plan ->
    # Create Stripe product
    {:ok, product} =
      Stripe.Product.create(%{
        name: plan.name,
        description: plan.description,
        metadata: %{tier: plan.tier}
      })

    # Create monthly price
    {:ok, monthly_price} =
      Stripe.Price.create(%{
        unit_amount: plan.monthly_amount,
        currency: "usd",
        product: product.id,
        recurring: %{
          interval: "month"
        }
      })

    # Create yearly price (10x monthly, billed annually)
    {:ok, yearly_price} =
      Stripe.Price.create(%{
        unit_amount: plan.monthly_amount * 10,
        currency: "usd",
        product: product.id,
        recurring: %{
          interval: "year"
        }
      })

    # Store monthly plan in our database
    {:ok, monthly_db_plan} =
      Repo.insert(%Plan{
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

    # Store yearly plan in our database
    {:ok, yearly_db_plan} =
      Repo.insert(%Plan{
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

# Store price IDs in application config for use in the webhook
# This makes subscription tier information available throughout the application
Application.put_env(:phxplate, :subscriptions, %{
  tiers:
    created_plans
    |> Enum.map(fn %{monthly: monthly, product: product} ->
      {String.to_atom(product.metadata["tier"]), %{price_id: monthly.stripe.id}}
    end)
    |> Enum.into(%{})
})

# Create super admin
# Uses environment variables if available, otherwise falls back to defaults
super_admin_email = System.get_env("SUPER_ADMIN_EMAIL") || "admin@example.com"
super_admin_password = System.get_env("SUPER_ADMIN_PASSWORD") || "changeme1234"

{:ok, super_admin} = %User{}
|> User.registration_changeset(%{
  email: super_admin_email,
  password: super_admin_password,
  role: :super_admin,
  onboarding_completed: true
})
|> Repo.insert()

# Create profile for super admin
profile = Repo.insert!(%Profile{
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

IO.puts("""
Production seed completed successfully!

Super Admin created:
Email: #{super_admin.email}
Password: #{super_admin_password}

Please make sure to change the super admin password after first login!
""")
