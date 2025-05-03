defmodule Phxplate.Repo.Migrations.CreatePlans do
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
  end
end
