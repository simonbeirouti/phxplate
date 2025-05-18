defmodule Phxplate.Subscriptions.Plan do
  @moduledoc """
  Schema for subscription plans.

  This schema represents a subscription plan in the system, storing details such as
  pricing information, features, and associated Stripe product and price IDs. Plans
  define the subscription options available to users and companies.
  """
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

  @doc """
  Changeset function for creating or updating a plan.

  Validates that required fields are present.

  ## Parameters
    - plan: The plan struct to change
    - attrs: Map of attributes to apply to the plan
  """
  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [:name, :description, :unit_amount, :currency, :interval, :metadata, :features, :stripe_price_id, :stripe_product_id])
    |> validate_required([:name, :unit_amount, :currency, :interval])
  end
end
