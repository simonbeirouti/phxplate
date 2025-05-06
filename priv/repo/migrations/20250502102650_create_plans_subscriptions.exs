defmodule Phxplate.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    create table(:plans) do
      add :name, :string, null: false
      add :description, :string
      add :unit_amount, :integer, null: false
      add :currency, :string, null: false
      add :interval, :string, null: false
      add :metadata, :map
      add :features, :map
      add :stripe_price_id, :string
      add :stripe_product_id, :string

      timestamps()
    end

    create index(:plans, [:stripe_price_id])
    create index(:plans, [:stripe_product_id])

    execute "CREATE TYPE subscription_status AS ENUM ('active', 'canceled', 'past_due', 'incomplete', 'trialing')"
    execute "CREATE TYPE paid_tier AS ENUM ('none', 'small', 'medium', 'large')"

    create table(:subscriptions) do
      add :stripe_customer_id, :string
      add :stripe_subscription_id, :string
      add :paid_tier, :paid_tier
      add :subscription_status, :subscription_status
      add :subscription_period_end, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :plan_id, references(:plans, on_delete: :restrict)

      timestamps()
    end

    create index(:subscriptions, [:user_id])
    create index(:subscriptions, [:plan_id])
    create index(:subscriptions, [:stripe_customer_id])
    create index(:subscriptions, [:stripe_subscription_id])
  end
end
