defmodule Phxplate.Subscriptions.Plan do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :name, :description, :unit_amount, :currency, :interval, :metadata, :features, :stripe_price_id, :stripe_product_id]}

  schema "plans" do
    field :name, :string
    field :description, :string
    field :unit_amount, :integer
    field :currency, :string
    field :interval, :string
    field :metadata, :map
    field :features, :map
    field :stripe_price_id, :string
    field :stripe_product_id, :string

    timestamps()
  end

  @doc false
  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:name, :description, :unit_amount, :currency, :interval, :metadata, :features, :stripe_price_id, :stripe_product_id])
    |> validate_required([:name, :unit_amount, :currency, :interval])
  end
end
