defmodule PhxplateWeb.Dashboard.User.BillingLive do
  use PhxplateWeb, :live_view

  # alias Phxplate.Accounts
  alias Phxplate.Subscriptions

  @impl true
  def mount(_params, _session, socket) do
    if socket.assigns[:current_user] do
      user = socket.assigns.current_user
      subscription = Subscriptions.get_user_subscription(user.id)

      socket =
        socket
        |> assign(:page_title, "Billing & Subscription")
        |> assign(:subscription, subscription)

      {:ok, socket}
    else
      {:ok,
       socket
       |> put_flash(:error, "You must be logged in to view your subscription.")
       |> redirect(to: ~p"/login")}
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
                  Current Plan: <%= String.capitalize(to_string(@subscription.paid_tier)) %>
                </h3>
                <div class="mt-2 max-w-xl text-sm text-gray-500">
                  <p>Status: <%= String.capitalize(to_string(@subscription.subscription_status)) %></p>
                  <p class="mt-1">
                    Next billing date: <%= Calendar.strftime(@subscription.subscription_period_end, "%B %d, %Y") %>
                  </p>
                </div>
              </div>
              <div class="mt-5 sm:ml-6 sm:mt-0">
                <.link
                  href="#"
                  class="inline-flex items-center rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                >
                  Manage Subscription
                </.link>
              </div>
            </div>
          </div>
        </div>

        <div class="overflow-hidden rounded-lg bg-white shadow">
          <div class="px-4 py-5 sm:p-6">
            <h3 class="text-lg font-medium leading-6 text-gray-900">Payment Method</h3>
            <div class="mt-2 max-w-xl text-sm text-gray-500">
              <p>Visa ending in 4242</p>
              <p class="mt-1">Expires 12/2025</p>
            </div>
            <div class="mt-5">
              <.link
                href="#"
                class="inline-flex items-center rounded-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 hover:bg-gray-50"
              >
                Update Payment Method
              </.link>
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
    """
  end
end
