defmodule PhxplateWeb.Dashboard.Account.BillingLive do
  use PhxplateWeb, :live_component

  alias Phxplate.Subscriptions
  import PhxplateWeb.Components.Subscription.PlanSelector

  @impl true
  def update(%{user: user} = assigns, socket) do
    subscription = Subscriptions.get_user_subscription(user.id)
    plans = Subscriptions.list_all_plans()

    socket =
      socket
      |> assign(assigns)
      |> assign(:subscription, subscription)
      |> assign(:plans, plans)
      |> assign(:show_plans_modal, false)
      |> assign(:loading, false)
      |> assign(:loading_payment, false)
      |> assign(:checkout_url, nil)
      |> assign(:show_cancel_confirm, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("show_plans_modal", _, socket) do
    {:noreply, assign(socket, :show_plans_modal, true)}
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
      {:ok, %Stripe.Session{url: checkout_url}} ->
        # Redirect to Stripe checkout - use redirect for external URLs
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:checkout_url, checkout_url)
         |> redirect(external: checkout_url)}

      {:ok, _updated} ->
        # Plan was updated directly (existing subscription)
        subscription = Subscriptions.get_user_subscription(user.id)

        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:subscription, subscription)
         |> assign(:show_plans_modal, false)
         |> put_flash(:info, "Your subscription has been updated to #{plan.name}.")}

      {:error, _error} ->
        # Handle error
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:show_plans_modal, false)
         |> put_flash(:error, "Failed to update subscription. Please try again later.")}
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
        send(self(), {:flash_msg, :info, "Your subscription has been cancelled and will end at the end of the billing period."})
        {:noreply, assign(socket, :show_cancel_confirm, false)}

      {:error, _reason} ->
        send(self(), {:flash_msg, :error, "There was an error cancelling your subscription. Please try again."})
        {:noreply, socket}
    end
  end

  def handle_event("reactivate_subscription", _, socket) do
    case Phxplate.Subscriptions.admin_update_subscription_status(socket.assigns.subscription, :active) do
      {:ok, updated_subscription} ->
        {:noreply,
         socket
         |> assign(:subscription, updated_subscription)
         |> put_flash(:info, "Your subscription has been reactivated and will continue to bill normally.")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "There was an error reactivating your subscription. Please try again.")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-4">
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
                      "inline-flex items-center rounded-md px-2 py-1 text-xs font-medium #{
                        case @subscription.subscription_status do
                          :active -> "bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20"
                          :canceled -> "bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/20"
                          :past_due -> "bg-yellow-50 text-yellow-700 ring-1 ring-inset ring-yellow-600/20"
                          _ -> "bg-gray-50 text-gray-700 ring-1 ring-inset ring-gray-600/20"
                        end
                      }"
                    }>
                      {String.capitalize(to_string(@subscription.subscription_status))}
                    </span>
                  </div>
                  <p class="mt-1 text-gray-500">Billing Frequency: {String.capitalize(@subscription.plan.interval)}ly</p>
                  <%= if @subscription.subscription_status == :canceled do %>
                    <p class="mt-1 text-red-600">
                      Your subscription will end on {Calendar.strftime(@subscription.subscription_period_end, "%B %d, %Y")}
                    </p>
                    <p class="mt-2 text-gray-600">
                      Choose a new plan to continue your subscription after this date.
                    </p>
                  <% else %>
                    <p class="mt-1 text-gray-500">
                      Next billing date: {Calendar.strftime(@subscription.subscription_period_end, "%B %d, %Y")}
                    </p>
                  <% end %>
                </div>
              </div>
              <div class="mt-5 sm:ml-6 sm:mt-0">
                <%= if @subscription.subscription_status == :canceled do %>
                  <div class="flex gap-2">
                    <.button
                      phx-click="show_plans_modal"
                      phx-target={@myself}
                    >
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
                  <.button
                    phx-click="show_plans_modal"
                    phx-target={@myself}
                    disabled={@loading}
                  >
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
                <p>Cancel your current subscription. This will take effect at the end of your billing period ({Calendar.strftime(@subscription.subscription_period_end, "%B %d, %Y")}).</p>
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
                    <.button
                      phx-click="cancel_confirmation"
                      phx-target={@myself}
                    >
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
      <% else %>
        <div class="rounded-lg bg-white shadow">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900">No active subscription</h3>
            <div class="mt-2 max-w-xl text-sm text-gray-500">
              <p>Get started by selecting a subscription plan.</p>
            </div>
            <div class="mt-5">
              <.button
                phx-click="show_plans_modal"
                phx-target={@myself}
              >
                Choose a Plan
              </.button>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_plans_modal do %>
        <div class="relative z-50" aria-labelledby="modal-title" role="dialog" aria-modal="true">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

          <div class="fixed inset-0 z-50 w-screen overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pt-5 text-left shadow-xl transition-all sm:my-8 w-full sm:max-w-4xl sm:p-6">
                <div class="absolute right-0 top-0 hidden pr-4 pt-4 sm:block">
                  <.button
                    phx-click="hide_plans_modal"
                    phx-target={@myself}
                    variant="outline"
                  >
                    <span class="sr-only">Close</span>
                    <Lucideicons.x class="h-6 w-6" />
                  </.button>
                </div>

                <div class="text-center">
                  <h3 class="text-2xl font-semibold leading-6 text-gray-900" id="modal-title">
                    Available Plans
                  </h3>
                  <p class="mt-2 text-sm text-gray-500">Choose a plan that best fits your needs.</p>
                </div>

                <.plan_selector
                  plans={@plans}
                  current_user={@user}
                  current_subscription={@subscription}
                  target={@myself}
                />
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
