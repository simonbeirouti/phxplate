defmodule Phxplate.Subscriptions do
  @moduledoc """
  The Subscriptions context.
  """

  import Ecto.Query, warn: false
  alias Phxplate.Repo
  alias Phxplate.Subscriptions.{Subscription, Plan}
  alias Phxplate.Accounts.User

  require Logger

  @doc """
  Gets a subscription by ID.
  """
  def get_subscription!(id), do: Repo.get!(Subscription, id) |> Repo.preload(:plan)

  @doc """
  Gets a subscription by stripe_subscription_id.
  """
  def get_subscription_by_stripe_id(stripe_subscription_id) when is_binary(stripe_subscription_id) do
    case Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription_id) do
      nil -> {:error, :not_found}
      subscription -> {:ok, subscription |> Repo.preload(:plan)}
    end
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

  @doc """
  Gets a plan by ID.
  """
  def get_plan!(id), do: Repo.get!(Plan, id)

  @doc """
  Gets a plan by Stripe price ID.
  """
  def get_plan_by_stripe_price_id(stripe_price_id) do
    Repo.get_by(Plan, stripe_price_id: stripe_price_id)
  end

  @doc """
  Creates a checkout session for a user to subscribe to a plan.
  Handles both new subscriptions and changes to existing subscriptions.
  """
  def create_checkout_session(%User{} = user, %Plan{} = plan) do
    stripe_price_id = plan.stripe_price_id

    if is_nil(stripe_price_id) do
      {:error, "Plan does not have a Stripe price ID"}
    else
      # Use the router routes for success and cancel URLs
      success_url = "#{Application.get_env(:phxplate, :base_url)}/callbacks/stripe/success?session_id={CHECKOUT_SESSION_ID}"
      cancel_url = "#{Application.get_env(:phxplate, :base_url)}/callbacks/stripe/cancel"

      subscription = get_user_subscription(user.id)

      session_params = if subscription && subscription.stripe_customer_id do
        # For existing subscriptions, we'll create a new subscription and cancel the old one after success
        # This is the recommended approach by Stripe for changing plans
        %{
          mode: "subscription",
          customer: subscription.stripe_customer_id,
          success_url: success_url,
          cancel_url: cancel_url,
          client_reference_id: user.id,
          payment_method_types: ["card"],
          line_items: [
            %{
              price: stripe_price_id,
              quantity: 1
            }
          ]
        }
      else
        # For new subscriptions
        base_params = %{
          payment_method_types: ["card"],
          line_items: [
            %{
              price: stripe_price_id,
              quantity: 1
            }
          ],
          mode: "subscription",
          success_url: success_url,
          cancel_url: cancel_url,
          client_reference_id: user.id
        }

        # Add customer info
        if subscription && subscription.stripe_customer_id do
          Map.put(base_params, :customer, subscription.stripe_customer_id)
        else
          # Create customer with user email for new subscriptions
          Map.put(base_params, :customer_email, user.email)
        end
      end

      Logger.info("Creating Stripe checkout session with params: #{inspect(session_params)}")

      case Stripe.Session.create(session_params) do
        {:ok, session} ->
          Logger.info("Created Stripe checkout session: #{session.id}")
          {:ok, session}
        {:error, error} ->
          Logger.error("Failed to create Stripe checkout session: #{inspect(error)}")
          {:error, error}
      end
    end
  end

  @doc """
  Updates a user's subscription to a new plan.
  Always redirects to Stripe checkout to ensure payment details are collected.
  """
  def change_subscription_plan(%User{} = user, %Plan{} = plan) do
    # Always create a checkout session for the new plan
    # This ensures users go through Stripe checkout for payment details
    create_checkout_session(user, plan)
  end

  @doc """
  Cancels a user's subscription.
  """
  def cancel_subscription(%User{} = user) do
    case get_user_subscription(user.id) do
      nil ->
        {:error, "User does not have an active subscription"}

      %Subscription{stripe_subscription_id: subscription_id} = subscription ->
        case Stripe.Subscription.update(subscription_id, %{cancel_at_period_end: true}) do
          {:ok, _stripe_sub} ->
            # Update local subscription record
            update_subscription(subscription, %{
              subscription_status: :canceled
            })

          {:error, error} ->
            Logger.error("Failed to cancel Stripe subscription: #{inspect(error)}")
            {:error, error}
        end
    end
  end

  @doc """
  Process a charge from Stripe.
  """
  def process_charge(type, %Stripe.Charge{} = charge) do
    Logger.info("Processing #{type} charge: #{charge.id}")

    # Find the subscription by customer ID
    case Repo.get_by(Subscription, stripe_customer_id: charge.customer) do
      nil ->
        Logger.error("No subscription found for customer #{charge.customer}")
        {:error, :subscription_not_found}

      subscription ->
        # Log the successful payment
        Logger.info("Successful payment for subscription #{subscription.id}")
        {:ok, subscription}
    end
  end

  @doc """
  Acount total subscriptions on the platform
  """
  def count_active_subscriptions do
    Subscription
    |> where([s], s.subscription_status == :active)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Calculate total revenue on the platform
  """
  def calculate_total_revenue do
    Subscription
    |> where([s], s.subscription_status == :active)
    |> join(:inner, [s], p in assoc(s, :plan))
    |> select([s, p], sum(p.unit_amount))
    |> Repo.one() || 0
  end

  @doc """
  Admin-only function to update a subscription's status.
  This bypasses Stripe and only updates the local database record.
  Should only be used by super admins for administrative purposes.
  """
  def admin_update_subscription_status(subscription, status, actor \\ nil)
  def admin_update_subscription_status(%Subscription{} = subscription, status, actor) when status in [:active, :canceled, :past_due, :incomplete, :trialing] do
    case update_subscription(subscription, %{subscription_status: status}) do
      {:ok, updated_subscription} ->
        if actor do
          Phxplate.Tracking.track_user_activity(
            "subscription_status_update",
            %{id: subscription.user_id},
            actor,
            %{"status" => status}
          )
        end
        {:ok, updated_subscription}
      error -> error
    end
  end
  def admin_update_subscription_status(_subscription, _status, _actor), do: {:error, :invalid_status}

  @doc """
  Admin-only function to update a subscription's tier.
  This bypasses Stripe and only updates the local database record.
  Should only be used by super admins for administrative purposes.
  """
  def admin_update_subscription_tier(subscription, tier, actor \\ nil)
  def admin_update_subscription_tier(%Subscription{} = subscription, tier, actor) when tier in [:small, :medium, :large] do
    # Find a plan that matches the tier (using monthly plan as default)
    plans = list_all_plans()
    tier_string = Atom.to_string(tier)

    plan = plans
      |> Enum.find(fn {t, _} -> t == tier_string end)
      |> case do
        {_, %{monthly: plan}} when not is_nil(plan) -> plan
        _ -> nil
      end

    if plan do
      case update_subscription(subscription, %{
        paid_tier: tier,
        plan_id: plan.id
      }) do
        {:ok, updated_subscription} ->
          if actor do
            Phxplate.Tracking.track_user_activity(
              "subscription_tier_update",
              %{id: subscription.user_id},
              actor,
              %{"tier" => tier}
            )
          end
          {:ok, updated_subscription}
        error -> error
      end
    else
      {:error, :plan_not_found}
    end
  end
  def admin_update_subscription_tier(_subscription, _tier, _actor), do: {:error, :invalid_tier}

  @doc """
  Admin-only function to create a subscription for a user.
  This bypasses Stripe and only creates a local database record.
  Should only be used by super admins for administrative purposes.
  """
  def admin_create_subscription(user_id, tier, status) when tier in [:small, :medium, :large] and status in [:active, :canceled, :past_due, :incomplete, :trialing] do
    # Find a plan that matches the tier (using monthly plan as default)
    plans = list_all_plans()
    tier_string = Atom.to_string(tier)

    plan = plans
      |> Enum.find(fn {t, _} -> t == tier_string end)
      |> case do
        {_, %{monthly: plan}} when not is_nil(plan) -> plan
        _ -> nil
      end

    if plan do
      attrs = %{
        user_id: user_id,
        paid_tier: tier,
        plan_id: plan.id,
        subscription_status: status,
        stripe_customer_id: "admin_created_#{user_id}",
        stripe_subscription_id: "admin_created_#{user_id}"
      }
      create_subscription(attrs)
    else
      {:error, :plan_not_found}
    end
  end
  def admin_create_subscription(_user_id, _tier, _status), do: {:error, :invalid_parameters}

end
