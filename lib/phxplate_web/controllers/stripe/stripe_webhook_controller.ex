defmodule PhxplateWeb.StripeWebhookController do
  use PhxplateWeb, :controller
  require Logger

  plug Stripe.WebhookPlug,
    secret: {Application, :get_env, [:stripity_stripe, :webhook_secret]},
    handler: __MODULE__

  alias Phxplate.Accounts
  alias Phxplate.Subscriptions

  def webhook(conn, params) do
    case params["type"] do
      "checkout.session.completed" -> handle_checkout_completed(params["data"]["object"])
      "customer.subscription.updated" -> handle_subscription_updated(params["data"]["object"])
      "customer.subscription.deleted" -> handle_subscription_deleted(params["data"]["object"])
      _ -> Logger.info("Received unhandled Stripe event type: #{params["type"]}")
    end

    json(conn, %{received: true})
  end

  defp handle_checkout_completed(session) do
    if session["mode"] == "subscription" && session["payment_status"] == "paid" do
      user_id = session["client_reference_id"]
      user = Accounts.get_user!(user_id)

      subscription =
        Stripe.Subscription.retrieve(session["subscription"], expand: ["items.data.price"])

      case subscription do
        {:ok, sub} ->
          paid_tier =
            determine_tier_from_price_id(
              sub.items.data
              |> List.first()
              |> Map.get(:price)
              |> Map.get(:id)
            )

          status = map_stripe_status(sub.status)

          subscription_attrs = %{
            stripe_customer_id: session["customer"],
            stripe_subscription_id: session["subscription"],
            paid_tier: paid_tier,
            subscription_status: status,
            user_id: user.id,
            subscription_period_end: DateTime.from_unix!(sub.current_period_end)
          }

          case Subscriptions.create_subscription(subscription_attrs) do
            {:ok, _subscription} ->
              # Update user role to admin after successful subscription
              Accounts.update_user(user, %{role: :admin})
              Logger.info("Processed checkout.session.completed for user #{user.id}")

            {:error, changeset} ->
              Logger.error("Failed to create subscription: #{inspect(changeset.errors)}")
          end

        {:error, error} ->
          Logger.error(
            "Failed to retrieve subscription #{session["subscription"]} after checkout: #{inspect(error)}"
          )
      end
    end
  end

  defp handle_subscription_updated(subscription) do
    case Subscriptions.get_subscription_by_stripe_id(subscription["id"]) do
      nil ->
        Logger.warning(
          "Received subscription.updated for unknown subscription ID: #{subscription["id"]}"
        )

      sub ->
        paid_tier =
          determine_tier_from_price_id(
            subscription["items"]["data"]
            |> List.first()
            |> Map.get(:price)
            |> Map.get(:id)
          )

        status = map_stripe_status(subscription["status"])

        attrs = %{
          paid_tier: paid_tier,
          subscription_status: status,
          subscription_period_end: DateTime.from_unix!(subscription["current_period_end"])
        }

        case Subscriptions.update_subscription(sub, attrs) do
          {:ok, updated_sub} ->
            # Update user role based on subscription status
            user = Accounts.get_user!(updated_sub.user_id)
            new_role = if status == :active, do: :admin, else: :basic
            Accounts.update_user(user, %{role: new_role})
            Logger.info("Processed customer.subscription.updated for user #{user.id}")

          {:error, changeset} ->
            Logger.error("Failed to update subscription: #{inspect(changeset.errors)}")
        end
    end
  end

  defp handle_subscription_deleted(subscription) do
    case Subscriptions.get_subscription_by_stripe_id(subscription["id"]) do
      nil ->
        Logger.warning(
          "Received subscription.deleted for unknown subscription ID: #{subscription["id"]}"
        )

      sub ->
        attrs = %{
          subscription_status: :canceled,
          subscription_period_end: DateTime.from_unix!(subscription["current_period_end"])
        }

        case Subscriptions.update_subscription(sub, attrs) do
          {:ok, updated_sub} ->
            # Revert user role to basic
            user = Accounts.get_user!(updated_sub.user_id)
            Accounts.update_user(user, %{role: :basic})
            Logger.info("Processed customer.subscription.deleted for user #{user.id}")

          {:error, changeset} ->
            Logger.error("Failed to update subscription: #{inspect(changeset.errors)}")
        end
    end
  end

  defp determine_tier_from_price_id(price_id) do
    Enum.find_value(Application.get_env(:phxplate, :subscriptions)[:tiers], fn {key, data} ->
      if data.price_id == price_id, do: key, else: nil
    end)
  end

  defp map_stripe_status("active"), do: :active
  defp map_stripe_status("trialing"), do: :trialing
  defp map_stripe_status("past_due"), do: :past_due
  defp map_stripe_status("canceled"), do: :canceled
  defp map_stripe_status("incomplete"), do: :incomplete
  defp map_stripe_status("incomplete_expired"), do: :canceled
  defp map_stripe_status("unpaid"), do: :past_due
  defp map_stripe_status(_other), do: nil
end
