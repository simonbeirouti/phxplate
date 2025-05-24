defmodule PhxplateWeb.StripeController do
  @moduledoc """
  Controller for handling Stripe payment and subscription related functionality.

  This controller implements the Stripe.WebhookHandler behaviour to process
  Stripe webhook events such as successful charges, subscription updates,
  payment failures, etc. It also handles success and cancel callbacks for
  the Stripe Checkout flow.
  """
  use PhxplateWeb, :controller
  require Logger

  alias Phxplate.Repo
  alias Phxplate.Accounts
  alias Phxplate.Subscriptions
  alias Phxplate.Subscriptions.{Subscription, Plan}

  @behaviour Stripe.WebhookHandler

  @metadata_version "1.0"

  @doc """
  Implements the Stripe.WebhookHandler callback to process Stripe events.

  Handles various Stripe events like subscription changes, payment failures,
  and successful charges. Logs results and sends alerts as needed.
  """
  @impl true
  def handle_event(%Stripe.Event{} = event) do
    result =
      case process_event(event) do
        :ok -> :ok
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
        :error -> {:error, :unknown_error}
      end

    case result do
      :ok ->
        Logger.debug("✅ #{inspect(event.type)}")
        alert(event, :ok)
        :ok

      {:error, reason} ->
        Logger.error("❌ #{inspect(event.type)}: #{inspect(reason)}")
        alert(event, {:error, reason})
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("❌ #{inspect(event.type)}: #{inspect(error)}")
      alert(event, {:error, error})
      {:error, error}
  end

  # Handle successful charge events
  defp process_event(%Stripe.Event{
         type: type,
         data: %{object: %Stripe.Charge{metadata: %{"version" => @metadata_version}} = charge}
       })
       when type in ["charge.succeeded", "charge.captured"] do
    case Subscriptions.process_charge(type, charge) do
      {:ok, _subscription} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Handle invoice payment succeeded event
  defp process_event(%Stripe.Event{
         type: "invoice.payment_succeeded",
         data: %{object: %Stripe.Invoice{subscription: subscription_id} = invoice}
       }) do
    case Subscriptions.get_subscription_by_stripe_id(subscription_id) do
      {:ok, subscription} ->
        case Subscriptions.update_subscription(subscription, %{
          subscription_status: :active,
          subscription_period_end: DateTime.from_unix!(invoice.period_end)
        }) do
          {:ok, _} ->
            Logger.info("Updated subscription status to active for #{subscription_id}")
            :ok
          {:error, reason} ->
            Logger.error("Failed to update subscription: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, _} ->
        Logger.error("Subscription not found for #{subscription_id}")
        {:error, :subscription_not_found}
    end
  end

  # Handle subscription created event
  defp process_event(%Stripe.Event{
         type: "customer.subscription.created",
         data: %{object: %Stripe.Subscription{} = stripe_subscription}
       }) do
    handle_subscription_update(stripe_subscription)
  end

  # Handle subscription updated event
  defp process_event(%Stripe.Event{
         type: "customer.subscription.updated",
         data: %{object: %Stripe.Subscription{} = stripe_subscription}
       }) do
    handle_subscription_update(stripe_subscription)
  end

  # Handle subscription deleted/canceled event
  defp process_event(%Stripe.Event{
         type: "customer.subscription.deleted",
         data: %{object: %Stripe.Subscription{id: subscription_id}}
       }) do
    case Subscriptions.get_subscription_by_stripe_id(subscription_id) do
      {:ok, subscription} ->
        case Subscriptions.update_subscription(subscription, %{
          subscription_status: :canceled
        }) do
          {:ok, _} ->
            Logger.info("Subscription #{subscription_id} marked as canceled")
            :ok
          {:error, reason} ->
            Logger.error("Failed to update subscription: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, _} ->
        Logger.error("Subscription not found for #{subscription_id}")
        {:error, :subscription_not_found}
    end
  end

  # Handle checkout session completed event
  defp process_event(%Stripe.Event{
         type: "checkout.session.completed",
         data: %{object: %Stripe.Session{customer: customer_id, subscription: subscription_id, client_reference_id: user_id} = _session}
       }) do
    with {:ok, stripe_subscription} <- Stripe.Subscription.retrieve(subscription_id, []),
         {:ok, price} <- get_price_from_subscription(stripe_subscription),
         {:ok, plan} <- get_plan_by_stripe_price_id(price.id) do

      # Check if user already has a subscription
      case Subscriptions.get_user_subscription(user_id) do
        %Subscription{stripe_subscription_id: old_subscription_id} = existing_subscription when not is_nil(old_subscription_id) ->
          # User is changing plans - update the existing subscription record with the new subscription ID
          # and cancel the old subscription if it's different
          if old_subscription_id != subscription_id do
            # Cancel the old subscription (at period end to avoid prorating)
            Logger.info("Canceling old subscription #{old_subscription_id} for user #{user_id}")
            Stripe.Subscription.update(old_subscription_id, %{cancel_at_period_end: true})
          end

          # Update the subscription record with the new subscription ID
          {:ok, _updated} = Subscriptions.update_subscription(existing_subscription, %{
            stripe_subscription_id: subscription_id,
            stripe_customer_id: customer_id,
            subscription_status: subscription_status_from_stripe(stripe_subscription.status),
            subscription_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
            plan_id: plan.id,
            paid_tier: plan.metadata["tier"]
          })

          Logger.info("Updated subscription for user #{user_id} to plan #{plan.id}")
          :ok

        _ ->
          # New subscription - create a new subscription record
          {:ok, _subscription} = create_subscription_for_user(user_id, customer_id, stripe_subscription, plan)
          Logger.info("Created new subscription for user #{user_id} with plan #{plan.id}")
          :ok
      end
    else
      {:error, reason} ->
        Logger.error("Failed to process checkout session: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Handle payment method attached event
  defp process_event(%Stripe.Event{
         type: "payment_method.attached",
         data: %{object: %Stripe.PaymentMethod{customer: customer_id} = _payment_method}
       }) do
    # Find user by stripe customer ID and update their payment method if needed
    case find_subscription_by_customer_id(customer_id) do
      {:ok, _subscription} ->
        Logger.info("Payment method attached for customer #{customer_id}")
        :ok
      {:error, reason} ->
        Logger.error("Failed to process payment method: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Handle payment failed event
  defp process_event(%Stripe.Event{
         type: "invoice.payment_failed",
         data: %{object: %Stripe.Invoice{subscription: subscription_id}}
       }) do
    case Subscriptions.get_subscription_by_stripe_id(subscription_id) do
      {:ok, subscription} ->
        case Subscriptions.update_subscription(subscription, %{
          subscription_status: :past_due
        }) do
          {:ok, _} ->
            Logger.info("Subscription #{subscription_id} marked as past_due due to payment failure")
            :ok
          {:error, reason} ->
            Logger.error("Failed to update subscription: #{inspect(reason)}")
            {:error, reason}
        end
      {:error, _} ->
        Logger.error("Subscription not found for #{subscription_id}")
        {:error, :subscription_not_found}
    end
  end

  # Default handler for unhandled events
  defp process_event(%Stripe.Event{type: type}) do
    Logger.info("Unhandled Stripe event: #{type}")
    :ok
  end

  # Helper function to handle subscription updates
  defp handle_subscription_update(%Stripe.Subscription{id: subscription_id, customer: customer_id} = stripe_subscription) do
    status = subscription_status_from_stripe(stripe_subscription.status)

    with {:ok, price} <- get_price_from_subscription(stripe_subscription),
         {:ok, plan} <- get_plan_by_stripe_price_id(price.id),
         {:ok, subscription} <- Subscriptions.get_subscription_by_stripe_id(subscription_id) do

      Subscriptions.update_subscription(subscription, %{
        subscription_status: status,
        subscription_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
        plan_id: plan.id
      })
    else
      nil ->
        # Subscription not found, try to find the user by customer ID
        case find_user_by_customer_id(customer_id) do
          {:ok, user} ->
            with {:ok, price} <- get_price_from_subscription(stripe_subscription),
                 {:ok, plan} <- get_plan_by_stripe_price_id(price.id) do
              create_subscription_for_user(user.id, customer_id, stripe_subscription, plan)
            end
          {:error, _} ->
            Logger.error("User not found for customer #{customer_id}")
            {:error, :user_not_found}
        end
      {:error, reason} ->
        Logger.error("Failed to update subscription: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helper to create or update a subscription
  defp create_or_update_subscription(user_id, customer_id, stripe_subscription, plan) do
    status = subscription_status_from_stripe(stripe_subscription.status)

    case Subscriptions.get_user_subscription(user_id) do
      nil ->
        # Create new subscription
        create_subscription_for_user(user_id, customer_id, stripe_subscription, plan)
      subscription ->
        # Update existing subscription
        Subscriptions.update_subscription(subscription, %{
          stripe_subscription_id: stripe_subscription.id,
          stripe_customer_id: customer_id,
          subscription_status: status,
          subscription_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
          plan_id: plan.id,
          paid_tier: plan.metadata["tier"]
        })
    end
  end

  # Helper to create a new subscription for a user
  defp create_subscription_for_user(user_id, customer_id, stripe_subscription, plan) do
    status = subscription_status_from_stripe(stripe_subscription.status)

    Subscriptions.create_subscription(%{
      user_id: user_id,
      stripe_customer_id: customer_id,
      stripe_subscription_id: stripe_subscription.id,
      subscription_status: status,
      subscription_period_end: DateTime.from_unix!(stripe_subscription.current_period_end),
      plan_id: plan.id,
      paid_tier: plan.metadata["tier"]
    })
  end

  # Helper to find a user by Stripe customer ID
  defp find_user_by_customer_id(customer_id) do
    case Repo.get_by(Subscription, stripe_customer_id: customer_id) do
      nil -> {:error, :not_found}
      subscription -> {:ok, Accounts.get_user!(subscription.user_id)}
    end
  end

  # Helper to find a subscription by Stripe customer ID
  defp find_subscription_by_customer_id(customer_id) do
    case Repo.get_by(Subscription, stripe_customer_id: customer_id) do
      nil -> {:error, :not_found}
      subscription -> {:ok, subscription}
    end
  end

  # Helper to get the price from a subscription
  defp get_price_from_subscription(%Stripe.Subscription{items: %{data: [%{price: price} | _]}}) do
    {:ok, price}
  end
  defp get_price_from_subscription(_), do: {:error, :price_not_found}

  # Helper to get a plan by Stripe price ID
  defp get_plan_by_stripe_price_id(price_id) do
    case Repo.get_by(Phxplate.Subscriptions.Plan, stripe_price_id: price_id) do
      nil -> {:error, :plan_not_found}
      plan -> {:ok, plan}
    end
  end

  # Convert Stripe subscription status to our internal status
  defp subscription_status_from_stripe(status) do
    case status do
      "active" -> :active
      "canceled" -> :canceled
      "incomplete" -> :incomplete
      "incomplete_expired" -> :canceled
      "past_due" -> :past_due
      "trialing" -> :trialing
      "unpaid" -> :past_due
      _ -> :incomplete
    end
  end

  # Logging helpers
  defp alert(%Stripe.Event{} = event, :ok) do
    Logger.debug("Stripe event: #{event.type} #{event.id}")
  end

  defp alert(%Stripe.Event{} = event, {:error, error}) do
    Logger.error("Stripe event: #{event.type} #{event.id} Error: #{inspect(error)}")
  end

  @doc """
  Handles successful Stripe Checkout sessions.

  Retrieves the checkout session details from Stripe, processes the subscription,
  and redirects the user to their account page with a success message.

  ## Parameters

  * `session_id` - The ID of the Stripe checkout session
  """
  def success(conn, %{"session_id" => session_id}) do
    # Retrieve the checkout session to get subscription details
    case Stripe.Session.retrieve(session_id) do
      {:ok, session} ->
        # Process the successful checkout session
        process_successful_checkout(session)
        conn
        |> put_flash(:info, "Your subscription has been updated successfully.")
        |> Phoenix.Controller.redirect(to: "/dashboard/account?tab=subscription")
      {:error, error} ->
        Logger.error("Failed to retrieve checkout session: #{inspect(error)}")
        conn
        |> put_flash(:error, "There was an error processing your subscription. Please try again.")
        |> Phoenix.Controller.redirect(to: "/dashboard/account?tab=subscription")
    end
  end

  # Process a successful checkout session
  defp process_successful_checkout(session) do
    Logger.info("Processing successful checkout: #{inspect(session.id)}")

    # Get the user ID from the client_reference_id
    user_id = String.to_integer(session.client_reference_id)

    # If this is a subscription checkout, retrieve the subscription
    if session.subscription do
      case Stripe.Subscription.retrieve(session.subscription) do
        {:ok, subscription} ->
          # Get the plan from the subscription
          [subscription_item | _] = subscription.items.data
          price_id = subscription_item.price.id

          # Find the plan by stripe_price_id
          plan = Repo.get_by(Plan, stripe_price_id: price_id)

          if plan do
            # Create or update the subscription
            create_or_update_subscription(user_id, session.customer, subscription, plan)
          else
            Logger.error("Plan not found for price_id: #{price_id}")
          end

        {:error, error} ->
          Logger.error("Failed to retrieve subscription: #{inspect(error)}")
      end
    end
  end

  @doc """
  Handles canceled Stripe Checkout sessions.

  Redirects the user to their account page with a message indicating
  that the subscription change was canceled.
  """
  def cancel(conn, _params) do
    # Redirect to billing page after canceled checkout with subscription tab selected
    conn
    |> put_flash(:error, "Your subscription was not updated.")
    |> Phoenix.Controller.redirect(to: "/dashboard/account?tab=subscription")
  end

  @doc """
  Handles Stripe webhook events.

  Verifies the Stripe signature, processes the event, and returns
  an appropriate response. Currently commented out.
  """
  # def webhook(conn, _params) do
  #   {:ok, body, _conn} = Plug.Conn.read_body(conn)
  #   signature = Plug.Conn.get_req_header(conn, "stripe-signature") |> List.first()

  #   secret = Application.get_env(:stripity_stripe, :webhook_secret)
  #   Logger.info("Processing Stripe webhook with signature: #{signature}")

  #   case Stripe.Webhook.construct_event(body, signature, secret) do
  #     {:ok, event} ->
  #       Logger.info("Successfully verified Stripe webhook: #{event.type}")
  #       handle_event(event)
  #       Plug.Conn.send_resp(conn, 200, "")

  #     {:error, reason} ->
  #       Logger.error("Failed to verify webhook: #{inspect(reason)}")
  #       Plug.Conn.send_resp(conn, 400, "")
  #   end
  # end
end
