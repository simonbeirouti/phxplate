# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Phxplate.Repo.insert!(%Phxplate.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Phxplate.Repo
alias Phxplate.Accounts.{User, Profile}
alias Phxplate.Companies.{Company, Employee}
alias Phxplate.Subscriptions.Subscription

# Store all created records
created_data = %{
  super_admins: [],
  admins: [],
  basic_users: [],
  companies: [],
  employees: [],
  profiles: [],
  subscriptions: [],
  plans: []
}

# Clear existing data
Repo.delete_all(Phxplate.Accounts.UserToken)
Repo.delete_all(Profile)
Repo.delete_all(Employee)
Repo.delete_all(Company)
Repo.delete_all(Subscription)
Repo.delete_all(Phxplate.Subscriptions.Plan)
Repo.delete_all(User)

# Create products in Stripe with both monthly and yearly prices
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
      Repo.insert(%Phxplate.Subscriptions.Plan{
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
      Repo.insert(%Phxplate.Subscriptions.Plan{
        name: plan.name <> " (Yearly)",
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
Application.put_env(:phxplate, :subscriptions, %{
  tiers:
    created_plans
    |> Enum.map(fn %{monthly: monthly, product: product} ->
      {String.to_atom(product.metadata["tier"]), %{price_id: monthly.stripe.id}}
    end)
    |> Enum.into(%{})
})

# Add plans to created_data
all_plans = created_plans |> Enum.map(fn %{monthly: %{db: monthly}, yearly: %{db: yearly}} -> 
  [
    %{
      id: monthly.id,
      name: monthly.name,
      description: monthly.description,
      unit_amount: monthly.unit_amount,
      currency: monthly.currency,
      interval: monthly.interval,
      metadata: monthly.metadata,
      features: monthly.features,
      stripe_price_id: monthly.stripe_price_id,
      stripe_product_id: monthly.stripe_product_id
    },
    %{
      id: yearly.id,
      name: yearly.name,
      description: yearly.description,
      unit_amount: yearly.unit_amount,
      currency: yearly.currency,
      interval: yearly.interval,
      metadata: yearly.metadata,
      features: yearly.features,
      stripe_price_id: yearly.stripe_price_id,
      stripe_product_id: yearly.stripe_product_id
    }
  ]
end) |> List.flatten()

created_data = Map.put(created_data, :plans, all_plans)

# Create super admins (without subscriptions)
created_data = Enum.reduce(1..1, created_data, fn _, acc ->
  user = User.registration_changeset(%User{}, %{
    email: Faker.Internet.email(),
    password: "password1234",
    role: :super_admin
  })
  |> Repo.insert!()

  # Create profile for super admin
  profile = Repo.insert!(%Profile{
    first_name: Faker.Person.first_name(),
    last_name: Faker.Person.last_name(),
    bio: Faker.Lorem.paragraph(),
    avatar_url: Faker.Avatar.image_url(),
    phone: Faker.Phone.EnUs.phone(),
    location: Faker.Address.city(),
    website: Faker.Internet.url(),
    social_links: %{
      twitter: Faker.Internet.url(),
      linkedin: Faker.Internet.url(),
      github: Faker.Internet.url()
    },
    user_id: user.id
  })

  acc
  |> Map.update!(:super_admins, &[%{id: user.id, email: user.email, role: user.role, profile: profile} | &1])
  |> Map.update!(:profiles, &[profile | &1])
end)

# Create admins with varied subscriptions (large, medium, small)
created_data = Enum.reduce(1..3, created_data, fn index, acc ->
  user = User.registration_changeset(%User{}, %{
    email: Faker.Internet.email(),
    password: "password1234",
    role: :admin
  })
  |> Repo.insert!()

  # Create Stripe customer
  {:ok, stripe_customer} = Stripe.Customer.create(%{
    email: user.email,
    description: "Admin User"
  })

  # Add a test payment method  # Use Stripe's test token
  {:ok, token} = {:ok, %{id: "tok_visa"}}

  {:ok, _} = Stripe.Customer.update(stripe_customer.id, %{
    source: token.id
  })

  # Create Stripe subscription with different tiers based on index
  plan =
    case rem(index, 3) do
      1 -> Enum.at(created_plans, 2) # Large plan
      2 -> Enum.at(created_plans, 1) # Medium plan
      0 -> Enum.at(created_plans, 0) # Small plan
    end

  subscription_price_id = plan.monthly.stripe.id

  tier = String.to_atom(plan.product.metadata["tier"])

  {:ok, stripe_subscription} = Stripe.Subscription.create(%{
    customer: stripe_customer.id,
    items: [%{price: subscription_price_id}]
  })

  # Create subscription record
  subscription = Repo.insert!(%Subscription{
    user_id: user.id,
    stripe_customer_id: stripe_customer.id,
    stripe_subscription_id: stripe_subscription.id,
    paid_tier: tier,
    subscription_status: String.to_atom(stripe_subscription.status),
    subscription_period_end: DateTime.from_unix!(stripe_subscription.current_period_end)
  })

  # Create profile for admin
  profile = Repo.insert!(%Profile{
    first_name: Faker.Person.first_name(),
    last_name: Faker.Person.last_name(),
    bio: Faker.Lorem.paragraph(),
    avatar_url: Faker.Avatar.image_url(),
    phone: Faker.Phone.EnUs.phone(),
    location: Faker.Address.city(),
    website: Faker.Internet.url(),
    social_links: %{
      twitter: Faker.Internet.url(),
      linkedin: Faker.Internet.url(),
      github: Faker.Internet.url()
    },
    user_id: user.id
  })

  acc
  |> Map.update!(:admins, &[%{id: user.id, email: user.email, role: user.role, profile: profile, subscription: subscription} | &1])
  |> Map.update!(:profiles, &[profile | &1])
  |> Map.update!(:subscriptions, &[subscription | &1])
end)

# Create basic users (some with small subscriptions, some without)
created_data = Enum.reduce(1..3, created_data, fn index, acc ->
  user = User.registration_changeset(%User{}, %{
    email: Faker.Internet.email(),
    password: "password1234",
    role: :basic
  })
  |> Repo.insert!()

  # Only create subscriptions for some basic users
  {subscription, stripe_customer_id} = if rem(index, 2) == 0 do
    # Create subscription based on index (large, medium, small)
    plan =
      case rem(index, 3) do
        1 -> Enum.at(created_plans, 2) # Large plan
        2 -> Enum.at(created_plans, 1) # Medium plan
        0 -> Enum.at(created_plans, 0) # Small plan
      end

    # Create a Stripe customer
    {:ok, customer} =
      Stripe.Customer.create(%{
        email: user.email,
        description: "Admin user"
      })

    # Create a payment method using test token
    {:ok, payment_method} =
      Stripe.PaymentMethod.create(%{
        type: "card",
        card: %{
          token: "tok_visa"
        }
      })

    # Attach payment method to customer
    {:ok, _attached_payment} =
      Stripe.PaymentMethod.attach(%{
        payment_method: payment_method.id,
        customer: customer.id
      })

    # Set as default payment method
    {:ok, _updated_customer} =
      Stripe.Customer.update(customer.id, %{
        invoice_settings: %{
          default_payment_method: payment_method.id
        }
      })

    # Create a subscription (using monthly plan)
    {:ok, subscription} =
      Stripe.Subscription.create(%{
        customer: customer.id,
        items: [%{price: plan.monthly.stripe.id}]
      })

    # Store subscription in our database
    {:ok, db_subscription} =
      Repo.insert(%Subscription{
        user_id: user.id,
        stripe_customer_id: customer.id,
        stripe_subscription_id: subscription.id,
        subscription_status: String.to_atom(subscription.status),
        subscription_period_end: DateTime.from_unix!(subscription.current_period_end),
        paid_tier: String.to_atom(plan.product.metadata["tier"])
      })

    {db_subscription, customer.id}
  else
    {nil, nil}
  end

  # Create profile for basic user
  profile = Repo.insert!(%Profile{
    first_name: Faker.Person.first_name(),
    last_name: Faker.Person.last_name(),
    bio: Faker.Lorem.paragraph(),
    avatar_url: Faker.Avatar.image_url(),
    phone: Faker.Phone.EnUs.phone(),
    location: Faker.Address.city(),
    website: Faker.Internet.url(),
    social_links: %{
      twitter: Faker.Internet.url(),
      linkedin: Faker.Internet.url(),
      github: Faker.Internet.url()
    },
    user_id: user.id
  })

  acc = acc
  |> Map.update!(:basic_users, &[%{
    id: user.id,
    email: user.email,
    role: user.role,
    profile: profile,
    subscription: subscription,
    stripe_customer_id: stripe_customer_id
  } | &1])
  |> Map.update!(:profiles, &[profile | &1])

  if subscription do
    Map.update!(acc, :subscriptions, &[subscription | &1])
  else
    acc
  end
end)

# Create companies with employees
created_data = Enum.reduce(1..2, created_data, fn _, acc ->
  company = Repo.insert!(%Company{
    name: Faker.Company.name(),
    description: Faker.Company.bs(),
    address: Faker.Address.street_address(),
    phone: Faker.Phone.EnUs.phone(),
    email: Faker.Internet.email(),
    logo: Faker.Avatar.image_url(),
    website: Faker.Internet.url(),
    plan: "basic"
  })

  company_data = %{
    id: company.id,
    name: company.name,
    description: company.description,
    address: company.address,
    phone: company.phone,
    email: company.email,
    plan: company.plan,
    logo: company.logo,
    website: company.website
  }

  # Create employees for each company
  {employees, acc} = Enum.reduce(1..2, {[], acc}, fn _, {employees, acc} ->
    employee = Repo.insert!(%Employee{
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      email: Faker.Internet.email(),
      phone: Faker.Phone.EnUs.phone(),
      position: Faker.Company.bs(),
      department: Faker.Commerce.department(),
      salary: Enum.random(30_000..150_000),
      company_id: company.id
    })

    employee_data = %{
      id: employee.id,
      first_name: employee.first_name,
      last_name: employee.last_name,
      email: employee.email,
      phone: employee.phone,
      position: employee.position,
      department: employee.department,
      salary: employee.salary,
      company_id: employee.company_id
    }

    {[employee_data | employees], Map.update!(acc, :employees, &[employee_data | &1])}
  end)

  Map.update!(acc, :companies, &[Map.put(company_data, :employees, employees) | &1])
end)

# Write the data to a JSON file
json_data = Jason.encode!(created_data, pretty: true)
File.write!("priv/repo/seeds.json", json_data)

IO.puts("Seed data created successfully and written to seeds.json!")
