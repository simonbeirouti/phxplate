defmodule PhxplateWeb.Dashboard.User.BillingLive do
  use PhxplateWeb, :live_view

  alias Phxplate.Subscriptions

  @impl true
  def mount(params, _session, socket) do
    if socket.assigns[:current_user] do
      user = socket.assigns.current_user
      subscription = Subscriptions.get_user_subscription(user.id)
      plans = Subscriptions.list_all_plans()

      socket =
        socket
        |> assign(:page_title, "Billing & Subscription")
        |> assign(:subscription, subscription)
        |> assign(:plans, plans)
        |> assign(:show_plans_modal, false)
        |> assign(:loading, false)
        |> assign(:checkout_url, nil)
        |> handle_query_params(params)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to view your subscription.")
       |> redirect(to: ~p"/login")}
    end
  end

  # Handle query params for success/cancel redirects from Stripe
  defp handle_query_params(socket, %{"success" => "true"}) do
    socket
    |> put_flash(:info, "Your subscription has been successfully updated.")
  end

  defp handle_query_params(socket, %{"canceled" => "true"}) do
    socket
    |> put_flash(:info, "Your subscription change was canceled.")
  end

  defp handle_query_params(socket, _params), do: socket

  @impl true
  def handle_event("show_plans_modal", _, socket) do
    {:noreply, assign(socket, :show_plans_modal, true)}
  end

  def handle_event("hide_plans_modal", _, socket) do
    {:noreply, assign(socket, :show_plans_modal, false)}
  end

  def handle_event("update_payment_method", _, socket) do
    _user = socket.assigns.current_user
    subscription = socket.assigns.subscription

    if subscription && subscription.stripe_subscription_id do
      # Create a Stripe portal session for managing payment methods
      case Stripe.BillingPortal.Session.create(%{
        customer: subscription.stripe_customer_id,
        return_url: "#{Application.get_env(:phxplate, :base_url)}/dashboard/billing"
      }) do
        {:ok, %{url: portal_url}} ->
          {:noreply, redirect(socket, external: portal_url)}

        {:error, error} ->
          {:noreply, put_flash(socket, :error, "Could not access payment settings: #{inspect(error)}")}
      end
    else
      {:noreply, put_flash(socket, :error, "You need an active subscription to update payment methods.")}
    end
  end

  def handle_event("change_plan", %{"plan_id" => plan_id}, socket) do
    user = socket.assigns.current_user
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

      {:error, error} ->
        # Handle error
        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:show_plans_modal, false)
         |> put_flash(:error, "Failed to update subscription: #{inspect(error)}")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-8">
      <div class="text-2xl font-bold tracking-tight text-zinc-900">
        Billing & Subscription
      </div>

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
                  class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                >
                  Change Plan
                </button>
              </div>
            </div>
          </div>
        </div>

        <div class="overflow-hidden rounded-lg bg-white shadow">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900">Payment Method</h3>
            <div class="mt-2 max-w-xl text-sm text-gray-500">
              <p>Payment method on file</p>
              <p class="mt-1">Managed by Stripe</p>
            </div>
            <div class="mt-5">
              <button
                phx-click="update_payment_method"
                class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                Update Payment Method
              </button>
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
    </div>

    <%= if @show_plans_modal do %>
      <div class="relative z-50" aria-labelledby="modal-title" role="dialog" aria-modal="true">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>

        <div class="fixed inset-0 z-50 w-screen overflow-y-auto">
          <div class="flex min-h-full items-end justify-center p-4 text-center sm:items-center sm:p-0">
            <div class="relative transform overflow-hidden rounded-lg bg-white px-4 pb-4 pt-5 text-left shadow-xl transition-all sm:my-8 sm:w-full sm:max-w-4xl sm:p-6">
              <div class="absolute right-0 top-0 hidden pr-4 pt-4 sm:block">
                <button
                  phx-click="hide_plans_modal"
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

              <div class="mt-8 grid grid-cols-1 gap-4 sm:grid-cols-3">
                <%= for {tier, plans} <- @plans do %>
                  <div class="rounded-lg border border-gray-200 bg-white p-6 shadow-sm">
                    <h3 class="text-lg font-semibold text-gray-900">
                      {String.capitalize(tier)} Plan
                      <%= if @subscription && @subscription.paid_tier == tier do %>
                        <span class="ml-2 inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
                          Current Tier
                        </span>
                      <% end %>
                    </h3>

                    <div class="mt-4 space-y-4">
                      <%= for interval <- ["monthly", "yearly"] do %>
                        <% plan = if interval == "monthly", do: plans.monthly, else: plans.yearly %>
                        <div class="flex items-center justify-between">
                          <div>
                            <p class="text-sm font-medium text-gray-900">
                              {interval |> String.capitalize()}
                              <%= if @subscription && @subscription.plan_id == plan.id do %>
                                <span class="ml-2 text-xs text-green-600">(Current)</span>
                              <% end %>
                            </p>
                            <p class="text-sm text-gray-500">${plan.unit_amount / 100}</p>
                          </div>
                          <%= if @subscription && @subscription.paid_tier == tier && @subscription.interval == plan.interval do %>
                            <span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">
                              Current Plan
                            </span>
                          <% else %>
                            <button
                              phx-click="change_plan"
                              phx-value-plan_id={plan.id}
                              class="rounded-md bg-indigo-600 px-2.5 py-1.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                            >
                              Select
                            </button>
                          <% end %>
                        </div>
                      <% end %>
                    </div>

                    <div class="mt-6">
                      <h4 class="text-sm font-medium text-gray-900">Features</h4>
                      <ul class="mt-2 space-y-2 text-sm text-gray-500">
                        <%= for {feature, value} <- plans.monthly.features do %>
                          <li class="flex items-center">
                            <svg
                              class="mr-2 h-4 w-4 text-green-500"
                              viewBox="0 0 20 20"
                              fill="currentColor"
                            >
                              <path
                                fill-rule="evenodd"
                                d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                                clip-rule="evenodd"
                              />
                            </svg>
                            {String.capitalize(to_string(feature))}: {value}
                          </li>
                        <% end %>
                      </ul>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
