defmodule PhxplateWeb.Dashboard.Account.BillingLive do
  @moduledoc """
  LiveComponent for managing user subscription and billing information.

  This component provides UI for viewing current subscription details,
  changing plans, updating payment methods, and cancelling subscriptions.
  It integrates with Stripe for checkout and payment processing.
  """
  use PhxplateWeb, :live_component

  alias Phxplate.Subscriptions
  import PhxplateWeb.Components.Subscription.PlanSelector
  import PhxplateWeb.Components.Subscription.SinglePurchaseSelector

  @doc """
  Updates the component with the user's subscription information.

  Retrieves the user's current subscription, available subscription plans,
  and single purchase products, then initializes the component state.
  """
  @impl true
  def update(%{platform_settings_updated: _msg}, socket) do
    # Handle platform settings updates only
    subscriptions_enabled = Subscriptions.subscriptions_enabled?()
    single_purchases_enabled = Subscriptions.single_purchases_enabled?()

    plans =
      if subscriptions_enabled do
        Subscriptions.list_all_plans()
      else
        %{}
      end

    single_purchase_plans =
      if single_purchases_enabled do
        Subscriptions.list_plans_by_product_type(:single_purchase)
      else
        []
      end

    {:ok,
     socket
     |> assign(:subscriptions_enabled, subscriptions_enabled)
     |> assign(:single_purchases_enabled, single_purchases_enabled)
     |> assign(:plans, plans)
     |> assign(:single_purchase_plans, single_purchase_plans)}
  end

  @impl true
  def update(%{plans_updated: _msg}, socket) do
    # Handle plan updates only
    subscriptions_enabled = socket.assigns[:subscriptions_enabled] || Subscriptions.subscriptions_enabled?()
    single_purchases_enabled = socket.assigns[:single_purchases_enabled] || Subscriptions.single_purchases_enabled?()

    plans =
      if subscriptions_enabled do
        Subscriptions.list_all_plans()
      else
        %{}
      end

    single_purchase_plans =
      if single_purchases_enabled do
        Subscriptions.list_plans_by_product_type(:single_purchase)
      else
        []
      end

    {:ok,
     socket
     |> assign(:plans, plans)
     |> assign(:single_purchase_plans, single_purchase_plans)}
  end

  @impl true
  def update(%{user: user} = assigns, socket) do
    subscription = Subscriptions.get_user_subscription(user.id)

    # Check platform settings to determine what to show
    subscriptions_enabled = Subscriptions.subscriptions_enabled?()
    single_purchases_enabled = Subscriptions.single_purchases_enabled?()

    plans =
      if subscriptions_enabled do
        Subscriptions.list_all_plans()
      else
        %{}
      end

    single_purchase_plans =
      if single_purchases_enabled do
        Subscriptions.list_plans_by_product_type(:single_purchase)
      else
        []
      end

    # Check for scheduled downgrade in subscription metadata
    scheduled_downgrade =
      if subscription && subscription.metadata && subscription.metadata["scheduled_plan_change"] do
        plan_id = subscription.metadata["scheduled_plan_change"]["plan_id"]
        effective_date_str = subscription.metadata["scheduled_plan_change"]["effective_date"]

        # Parse the effective_date string into a DateTime
        effective_date =
          case DateTime.from_iso8601(effective_date_str) do
            {:ok, datetime, _offset} ->
              datetime

            _ ->
              # If parsing fails, use the subscription period end as fallback
              subscription.subscription_period_end
          end

        new_plan = Subscriptions.get_plan!(plan_id)

        %{
          current_plan: subscription.plan.name,
          new_plan: new_plan.name,
          effective_date: effective_date
        }
      else
        nil
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:subscription, subscription)
      |> assign(:plans, plans)
      |> assign(:single_purchase_plans, single_purchase_plans)
      |> assign(:show_plans_modal, false)
      |> assign(:loading, false)
      |> assign(:loading_payment, false)
      |> assign(:checkout_url, nil)
      |> assign(:show_cancel_confirm, false)
      |> assign(:proration_info, %{})
      |> assign(:scheduled_downgrade, scheduled_downgrade)
      |> assign(:subscriptions_enabled, subscriptions_enabled)
      |> assign(:single_purchases_enabled, single_purchases_enabled)

    {:ok, socket}
  end

  # Helper function to calculate proration information
  defp calculate_proration_info(nil, _plans), do: %{}
  defp calculate_proration_info(%{subscription_status: :canceled}, _plans), do: %{}

  defp calculate_proration_info(subscription, plans) do
    current_plan = subscription.plan

    # Get today's date and the end of the billing period
    today = Date.utc_today()
    period_end = DateTime.to_date(subscription.subscription_period_end)

    # Calculate days remaining in billing period
    total_days_in_period =
      case current_plan.interval do
        # Approximate for simplicity
        "month" -> 30
        "year" -> 365
        _ -> 30
      end

    days_remaining = Date.diff(period_end, today)
    days_used = total_days_in_period - days_remaining

    # Calculate percentage of period remaining
    percent_remaining = Float.round(days_remaining / total_days_in_period * 100, 1)

    # For each plan tier, calculate the prorated cost if it's an upgrade
    Enum.reduce(plans, %{}, fn {tier, tier_plans}, acc ->
      # Get the plan with the same interval as the current subscription
      comparable_plan = Map.get(tier_plans, String.to_atom(current_plan.interval))

      if comparable_plan && comparable_plan.unit_amount > current_plan.unit_amount do
        # This is an upgrade - calculate prorated amount
        price_difference = comparable_plan.unit_amount - current_plan.unit_amount
        prorated_cost = Float.round(price_difference * days_remaining / total_days_in_period, 2)

        # Format for display
        formatted_full = format_currency(comparable_plan.unit_amount, comparable_plan.currency)
        formatted_prorated = format_currency(trunc(prorated_cost), comparable_plan.currency)

        Map.put(acc, tier, %{
          is_upgrade: true,
          plan_id: comparable_plan.id,
          full_price: formatted_full,
          prorated_price: formatted_prorated,
          percent_remaining: percent_remaining,
          days_remaining: days_remaining,
          days_used: days_used
        })
      else
        # Not an upgrade or no comparable plan
        acc
      end
    end)
  end

  # Helper function to format currency
  defp format_currency(amount, currency) do
    # Convert cents to dollars/euros/etc
    decimal_amount = amount / 100.0

    case currency do
      "usd" -> "$#{:erlang.float_to_binary(decimal_amount, decimals: 2)}"
      "eur" -> "€#{:erlang.float_to_binary(decimal_amount, decimals: 2)}"
      _ -> "#{:erlang.float_to_binary(decimal_amount, decimals: 2)} #{String.upcase(currency)}"
    end
  end

  @impl true
  def handle_event("show_plans_modal", _, socket) do
    # Calculate proration information for each plan if user has an active subscription
    proration_info = calculate_proration_info(socket.assigns.subscription, socket.assigns.plans)

    {:noreply,
     socket |> assign(:proration_info, proration_info) |> assign(:show_plans_modal, true)}
  end

  def handle_event("hide_plans_modal", _, socket) do
    {:noreply, assign(socket, :show_plans_modal, false)}
  end

  def handle_event("update_payment_method", _, socket) do
    socket = assign(socket, :loading_payment, true)
    subscription = socket.assigns.subscription

    if subscription && subscription.stripe_subscription_id do
      # Create a Stripe portal session for managing payment methods
      case Stripe.BillingPortal.Session.create(%{
             customer: subscription.stripe_customer_id,
             return_url: "#{Application.get_env(:phxplate, :base_url)}/dashboard/account"
           }) do
        {:ok, %{url: portal_url}} ->
          {:noreply,
           socket
           |> assign(:loading_payment, false)
           |> redirect(external: portal_url)}

        {:error, _error} ->
          {:noreply,
           socket
           |> assign(:loading_payment, false)
           |> put_flash(:error, "Could not access payment settings. Please try again later.")}
      end
    else
      {:noreply,
       socket
       |> assign(:loading_payment, false)
       |> put_flash(:error, "You need an active subscription to update payment methods.")}
    end
  end

  def handle_event("select_plan", %{"plan-id" => plan_id}, socket) do
    user = socket.assigns.user
    plan = Subscriptions.get_plan!(plan_id)

    socket = socket |> assign(:loading, true)

    case Subscriptions.change_subscription_plan(user, plan) do
      # Handle scheduled downgrade - no redirect needed
      {:ok, %{scheduled_downgrade: true} = downgrade_info} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:show_plans_modal, false)
         |> assign(:scheduled_downgrade, downgrade_info)
         |> put_flash(
           :info,
           "Your subscription will be downgraded to #{downgrade_info.new_plan} at the end of your current billing period (#{Calendar.strftime(downgrade_info.effective_date, "%B %d, %Y")})."
         )}

      # Handle upgrades and new subscriptions - redirect to Stripe checkout
      {:ok, %Stripe.Session{} = session} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:checkout_url, session.url)
         |> redirect(external: session.url)}

      {:error, _error} ->
        # Handle error
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:show_plans_modal, false)
         |> put_flash(:error, "Failed to complete payment. Please try again later.")}
    end
  end

  def handle_event("show_cancel_confirmation", _, socket) do
    {:noreply, assign(socket, :show_cancel_confirm, true)}
  end

  def handle_event("cancel_confirmation", _, socket) do
    {:noreply, assign(socket, :show_cancel_confirm, false)}
  end

  def handle_event("confirm_cancel_subscription", _, socket) do
    case Phxplate.Subscriptions.cancel_subscription(socket.assigns.user) do
      {:ok, _subscription} ->
        send(
          self(),
          {:flash_msg, :info,
           "Your subscription has been cancelled and will end at the end of the billing period."}
        )

        {:noreply, assign(socket, :show_cancel_confirm, false)}

      {:error, _reason} ->
        send(
          self(),
          {:flash_msg, :error,
           "There was an error cancelling your subscription. Please try again."}
        )

        {:noreply, socket}
    end
  end

  def handle_event("reactivate_subscription", _, socket) do
    case Phxplate.Subscriptions.admin_update_subscription_status(
           socket.assigns.subscription,
           :active,
           socket.assigns.user
         ) do
      {:ok, updated_subscription} ->
        {:noreply,
         socket
         |> assign(:subscription, updated_subscription)
         |> put_flash(
           :info,
           "Your subscription has been reactivated and will continue to bill normally."
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "There was an error reactivating your subscription. Please try again."
         )}
    end
  end

  def handle_event("purchase_product", %{"product-id" => product_id}, socket) do
    user = socket.assigns.user
    product = Subscriptions.get_plan!(product_id)

    socket = socket |> assign(:loading, true)

    case Subscriptions.create_single_purchase_checkout_session(user, product) do
      {:ok, %Stripe.Session{url: checkout_url}} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:show_plans_modal, false)
         |> redirect(external: checkout_url)}

      {:error, _error} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:show_plans_modal, false)
         |> put_flash(:error, "Failed to process purchase. Please try again later.")}
    end
  end

  @doc """
  Renders the subscription management UI.

  Displays the current subscription details, options to change plans,
  update payment methods, and cancel or reactivate subscriptions.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <%= if not @subscriptions_enabled and not @single_purchases_enabled do %>
        <div class="rounded-lg bg-gray-50 border border-gray-200 p-6 text-center">
          <Lucideicons.info class="h-8 w-8 mx-auto text-gray-400 mb-3" />
          <h3 class="text-lg font-medium text-gray-900 mb-2">Billing Not Available</h3>
          <p class="text-sm text-gray-600">
            Subscription and purchase options are currently disabled.
            Please contact support for assistance.
          </p>
        </div>
      <% else %>
        <%= if @subscription do %>
          <div class="overflow-hidden rounded-lg bg-white shadow">
            <div class="px-4 py-5 sm:p-6">
              <div class="sm:flex sm:items-center sm:justify-between">
                <div>
                  <h3 class="text-lg font-medium leading-6 text-gray-900">
                    Current Plan: {@subscription.plan.name}
                  </h3>
                  <div class="mt-2 max-w-xl text-sm">
                    <div class="flex items-center gap-2">
                      <p class="text-gray-500">Status:</p>
                      <span class={
                        case @subscription.subscription_status do
                          :active ->
                            "inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20"

                          :canceled ->
                            "inline-flex items-center rounded-md bg-red-50 px-2 py-1 text-xs font-medium text-red-700 ring-1 ring-inset ring-red-600/20"

                          :past_due ->
                            "inline-flex items-center rounded-md bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-700 ring-1 ring-inset ring-yellow-600/20"

                          :incomplete ->
                            "inline-flex items-center rounded-md bg-yellow-50 px-2 py-1 text-xs font-medium text-yellow-700 ring-1 ring-inset ring-yellow-600/20"

                          :trialing ->
                            "inline-flex items-center rounded-md bg-blue-50 px-2 py-1 text-xs font-medium text-blue-700 ring-1 ring-inset ring-blue-600/20"
                        end
                      }>
                        {String.capitalize(to_string(@subscription.subscription_status))}
                      </span>
                    </div>
                    <p class="mt-1 text-gray-500">
                      Billing Frequency: {String.capitalize(@subscription.plan.interval)}ly
                    </p>

                    <%= if @scheduled_downgrade do %>
                      <.alert class="my-4 space-y-2 flex flex-row items-center">
                        <Lucideicons.badge_check class="h-10 w-10 mr-3 mt-2" />
                        <div class="pb-2">
                          <.alert_title>Heads up!</.alert_title>
                          <.alert_description>
                            Your subscription will be downgraded from
                            <span class="font-semibold">{@scheduled_downgrade.current_plan}</span>
                            to <span class="font-semibold">{@scheduled_downgrade.new_plan}</span>
                          </.alert_description>
                        </div>
                      </.alert>
                    <% end %>
                    <%= if @subscription.subscription_status == :canceled do %>
                      <p class="mt-1 text-red-600">
                        Your subscription will end on {Calendar.strftime(
                          @subscription.subscription_period_end,
                          "%B %d, %Y"
                        )}
                      </p>
                      <p class="mt-2 text-gray-600">
                        Choose a new plan to continue your subscription after this date.
                      </p>
                    <% else %>
                      <p class="mt-1 text-gray-500">
                        Next billing date: {Calendar.strftime(
                          @subscription.subscription_period_end,
                          "%B %d, %Y"
                        )}
                      </p>
                    <% end %>
                  </div>
                </div>
                <div class="mt-5 sm:ml-6 sm:mt-0">
                  <%= if @subscription.subscription_status == :canceled do %>
                    <div class="flex gap-2">
                      <.button phx-click="show_plans_modal" phx-target={@myself}>
                        Choose New Plan
                      </.button>
                      <.button
                        phx-click="reactivate_subscription"
                        phx-target={@myself}
                        class="bg-green-600 hover:bg-green-500"
                      >
                        Reactivate Current Plan
                      </.button>
                    </div>
                  <% else %>
                    <.button phx-click="show_plans_modal" phx-target={@myself} disabled={@loading}>
                      <%= if @loading do %>
                        <div class="inline-block animate-spin h-4 w-4 mr-2 border-2 border-white rounded-full border-t-transparent" />
                        Changing...
                      <% else %>
                        Change Plan
                      <% end %>
                    </.button>
                  <% end %>
                </div>
              </div>
            </div>
          </div>

          <%= if @subscription.subscription_status != :canceled do %>
            <div class="overflow-hidden rounded-lg bg-white shadow">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium leading-6 text-gray-900">Cancel Subscription</h3>
                <div class="mt-2 max-w-xl text-sm text-gray-500">
                  <p>
                    Cancel your current subscription. This will take effect at the end of your billing period ({Calendar.strftime(
                      @subscription.subscription_period_end,
                      "%B %d, %Y"
                    )}).
                  </p>
                </div>
                <div class="mt-5">
                  <%= if @show_cancel_confirm do %>
                    <div class="flex gap-3">
                      <.button
                        phx-click="confirm_cancel_subscription"
                        phx-target={@myself}
                        variant="destructive"
                      >
                        Confirm Cancellation
                      </.button>
                      <.button phx-click="cancel_confirmation" phx-target={@myself}>
                        Keep Subscription
                      </.button>
                    </div>
                  <% else %>
                    <.button
                      phx-click="show_cancel_confirmation"
                      phx-target={@myself}
                      variant="destructive"
                    >
                      Cancel Subscription
                    </.button>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>

          <%= if @single_purchases_enabled and length(@single_purchase_plans) > 0 do %>
            <div class="px-4 py-5 sm:p-6">
              <.single_purchase_selector
                products={@single_purchase_plans}
                current_user={@user}
                target={@myself}
                loading={@loading}
                title="Additional Products"
                description="Purchase additional products and services to enhance your experience."
              />
            </div>
          <% end %>
        <% else %>
          <%= if @subscriptions_enabled or @single_purchases_enabled do %>
            <div class="rounded-lg bg-white shadow">
              <div class="px-4 py-5 sm:p-6">
                <h3 class="text-lg font-medium leading-6 text-gray-900">No active subscription</h3>
                <div class="mt-2 max-w-xl text-sm text-gray-500">
                  <p>
                    <%= if @subscriptions_enabled and @single_purchases_enabled do %>
                      Get started by selecting a subscription plan or purchasing a product.
                    <% else %>
                      <%= if @subscriptions_enabled do %>
                        Get started by selecting a subscription plan.
                      <% else %>
                        Browse available products for purchase.
                      <% end %>
                    <% end %>
                  </p>
                </div>
                <div class="mt-5">
                  <.button phx-click="show_plans_modal" phx-target={@myself}>
                    <%= if @subscriptions_enabled and @single_purchases_enabled do %>
                      View Plans & Products
                    <% else %>
                      <%= if @subscriptions_enabled do %>
                        Choose a Plan
                      <% else %>
                        View Products
                      <% end %>
                    <% end %>
                  </.button>
                </div>
              </div>
            </div>
          <% end %>
        <% end %>

        <%= if @show_plans_modal do %>
          <div class="relative z-50" aria-labelledby="modal-title" role="dialog" aria-modal="true">
            <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

            <div class="fixed inset-0 z-50 w-screen overflow-y-auto">
              <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
                <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pt-5 text-left shadow-xl transition-all sm:my-8 w-full sm:max-w-4xl sm:p-6">
                  <div class="absolute right-0 top-0 hidden pr-4 pt-4 sm:block">
                    <.button phx-click="hide_plans_modal" phx-target={@myself} variant="outline">
                      <span class="sr-only">Close</span>
                      <Lucideicons.x class="h-6 w-6" />
                    </.button>
                  </div>

                  <div class="text-center">
                    <h3 class="text-2xl font-semibold leading-6 text-gray-900" id="modal-title">
                      <%= if @subscriptions_enabled and @single_purchases_enabled do %>
                        Plans & Products
                      <% else %>
                        <%= if @subscriptions_enabled do %>
                          Subscription Plans
                        <% else %>
                          Products
                        <% end %>
                      <% end %>
                    </h3>
                    <p class="mt-2 text-sm text-gray-500">
                      <%= if @subscriptions_enabled and @single_purchases_enabled and length(@single_purchase_plans) > 0 do %>
                        Choose a subscription plan or purchase a one-time product.
                      <% else %>
                        <%= if @subscriptions_enabled do %>
                          Choose a plan that best fits your needs.
                        <% else %>
                          Select a product to purchase.
                        <% end %>
                      <% end %>
                    </p>
                  </div>

                  <%= if @subscriptions_enabled do %>
                    <.plan_selector
                      plans={@plans}
                      current_user={@user}
                      current_subscription={@subscription}
                      proration_info={@proration_info}
                      target={@myself}
                    />
                  <% end %>

                  <%= if @single_purchases_enabled and length(@single_purchase_plans) > 0 do %>
                    <div class="mt-8">
                      <.single_purchase_selector
                        products={@single_purchase_plans}
                        current_user={@user}
                        target={@myself}
                        loading={@loading}
                        title="One-Time Products"
                        description="Purchase additional products without a subscription."
                      />
                    </div>
                  <% end %>
                </div>
              </div>
            </div>
          </div>
        <% end %>
      <% end %>
    </div>
    """
  end


end
