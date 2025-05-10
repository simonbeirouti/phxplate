defmodule PhxplateWeb.Dashboard.Account.BillingLive do
  use PhxplateWeb, :live_component

  alias Phxplate.Subscriptions
  import PhxplateWeb.Components.Subscription.PlanSelector

  @impl true
  def update(%{user: user} = assigns, socket) do
    subscription = Subscriptions.get_user_subscription(user.id)
    plans = Subscriptions.list_all_plans()

    status_message = case assigns[:status] do
      "success" -> {:info, "Your subscription has been updated successfully."}
      "error" -> {:error, "There was an error processing your subscription. Please try again."}
      "canceled" -> {:info, "Your subscription change was canceled."}
      _ -> nil
    end

    socket =
      socket
      |> assign(assigns)
      |> assign(:subscription, subscription)
      |> assign(:plans, plans)
      |> assign(:show_plans_modal, false)
      |> assign(:loading, false)
      |> assign(:loading_payment, false)
      |> assign(:checkout_url, nil)

    socket = if status_message do
      {type, msg} = status_message
      put_flash(socket, type, msg)
    else
      socket
    end

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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <%= if @subscription do %>
        <div class="overflow-hidden rounded-lg bg-white shadow">
          <div class="px-4 py-5 sm:p-6">
            <div class="sm:flex sm:items-center sm:justify-between">
              <div>
                <h3 class="text-lg font-medium leading-6 text-gray-900">
                  Current Plan: {@subscription.plan.name}
                </h3>
                <div class="mt-2 max-w-xl text-sm text-gray-500">
                  <p>Status: {String.capitalize(to_string(@subscription.subscription_status))}</p>
                  <p class="mt-1">Billing Frequency: {String.capitalize(@subscription.plan.interval)}ly</p>
                  <p class="mt-1">
                    Next billing date: {Calendar.strftime(
                      @subscription.subscription_period_end,
                      "%B %d, %Y"
                    )}
                  </p>
                </div>
              </div>
              <div class="mt-5 sm:ml-6 sm:mt-0">
                <button
                  phx-click="show_plans_modal"
                  phx-target={@myself}
                  disabled={@loading}
                  class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <%= if @loading do %>
                    <div class="inline-block animate-spin h-4 w-4 mr-2 border-2 border-white rounded-full border-t-transparent" />
                    Changing...
                  <% else %>
                    Change Plan
                  <% end %>
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="overflow-hidden rounded-lg bg-white shadow">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900">Billing History</h3>
            <div class="mt-2 max-w-xl text-sm text-gray-500">
              <p>View and download your billing history.</p>
            </div>
            <div class="mt-5">
              <.link
                href="#"
                class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                View Billing History
              </.link>
            </div>
          </div>
        </div>
      <% else %>
        <div class="rounded-lg bg-white shadow">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900">No active subscription</h3>
            <div class="mt-2 max-w-xl text-sm text-gray-500">
              <p>Get started by selecting a subscription plan.</p>
            </div>
            <div class="mt-5">
              <.link
                href={~p"/pricing"}
                class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
              >
                View Plans
              </.link>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @show_plans_modal do %>
        <div class="relative z-50" aria-labelledby="modal-title" role="dialog" aria-modal="true">
          <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

          <div class="fixed inset-0 z-50 w-screen overflow-y-auto">
            <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
              <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-4xl sm:p-6">
                <div class="absolute right-0 top-0 hidden pr-4 pt-4 sm:block">
                  <button
                    phx-click="hide_plans_modal"
                    phx-target={@myself}
                    type="button"
                    class="rounded-md bg-white text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                  >
                    <span class="sr-only">Close</span>
                    <svg
                      class="h-6 w-6"
                      fill="none"
                      viewBox="0 0 24 24"
                      stroke-width="1.5"
                      stroke="currentColor"
                    >
                      <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                  </button>
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
