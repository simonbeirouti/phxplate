defmodule Phxplate.Repo.Migrations.CreateSubscriptions do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE subscription_status AS ENUM ('active', 'canceled', 'past_due', 'incomplete', 'trialing')"
    execute "CREATE TYPE paid_tier AS ENUM ('small', 'medium', 'large')"

    create table(:subscriptions) do
      add :stripe_customer_id, :string
      add :stripe_subscription_id, :string
      add :paid_tier, :paid_tier
      add :subscription_status, :subscription_status
      add :subscription_period_end, :utc_datetime
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:subscriptions, [:user_id])
    create index(:subscriptions, [:stripe_customer_id])
    create index(:subscriptions, [:stripe_subscription_id])
  end
end
