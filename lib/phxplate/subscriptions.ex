defmodule Phxplate.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  """

  import Ecto.Query, warn: false
  alias Phxplate.Repo
  alias Phxplate.Subscriptions.{Subscription, Plan}

  @doc """
  Gets a subscription by ID.
  """
  def get_subscription!(id), do: Repo.get!(Subscription, id) |> Repo.preload(:plan)

  @doc """
  Gets a subscription by stripe_subscription_id.
  """
  def get_subscription_by_stripe_id(stripe_subscription_id) do
    Subscription
    |> Repo.get_by(stripe_subscription_id: stripe_subscription_id)
    |> Repo.preload(:plan)
  end

  @doc """
  Creates a subscription.
  """
  def create_subscription(attrs \\ %{}) do
    %Subscription{}
    |> Subscription.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a subscription.
  """
  def update_subscription(%Subscription{} = subscription, attrs) do
    subscription
    |> Subscription.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a subscription.
  """
  def delete_subscription(%Subscription{} = subscription) do
    Repo.delete(subscription)
  end

  @doc """
  Gets a user's subscription.
  """
  def get_user_subscription(user_id) do
    Subscription
    |> where([s], s.user_id == ^user_id)
    |> Repo.one()
    |> Repo.preload(:plan)
  end

  @doc """
  Lists all plans grouped by tier with both monthly and yearly options.
  Returns a map of tiers, each containing their monthly and yearly plans.
  """
  def list_all_plans do
    plans =
      Plan
      |> order_by([p], asc: p.unit_amount)
      |> Repo.all()

    plans
    |> Enum.group_by(& &1.metadata["tier"])
    |> Enum.map(fn {tier, tier_plans} ->
      {tier,
       %{
         monthly: Enum.find(tier_plans, &(&1.interval == "month")),
         yearly: Enum.find(tier_plans, &(&1.interval == "year"))
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Lists all plans for a specific interval (month or year) ordered by amount.
  """
  def list_plans_by_interval(interval) when interval in ["month", "year"] do
    Plan
    |> where([p], p.interval == ^interval)
    |> order_by([p], asc: p.unit_amount)
    |> Repo.all()
  end
end
