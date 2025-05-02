defmodule PhxplateWeb.PricingLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Subscriptions

  @impl true
  def mount(_params, _session, socket) do
    # Get all plans grouped by tier
    plans = Subscriptions.list_all_plans()

    {:ok,
     assign(socket,
       page_title: "Pricing",
       page_description: "Choose the right plan for you",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com/pricing",
       plans: plans,
       selected_interval: "month"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-24 sm:py-32">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <div class="mx-auto max-w-4xl text-center">
          <h2 class="text-base font-semibold leading-7 text-indigo-600">Pricing</h2>
          <p class="mt-2 text-4xl font-bold tracking-tight text-gray-900 sm:text-5xl">
            Choose the right plan for&nbsp;you
          </p>
        </div>
        <div class="mx-auto mt-16 max-w-2xl rounded-3xl ring-1 ring-gray-200 sm:mt-20 lg:mx-0 lg:flex lg:max-w-none">
          <div class="p-8 sm:p-10 lg:flex-auto">
            <div class="flex justify-center space-x-4 mb-8">
              <button
                phx-click="toggle_interval"
                phx-value-interval="month"
                class={[
                  "px-4 py-2 text-sm font-semibold rounded-md",
                  if(@selected_interval == "month",
                    do: "bg-indigo-600 text-white",
                    else: "text-gray-700 hover:bg-gray-50"
                  )
                ]}
              >
                Monthly
              </button>
              <button
                phx-click="toggle_interval"
                phx-value-interval="year"
                class={[
                  "px-4 py-2 text-sm font-semibold rounded-md",
                  if(@selected_interval == "year",
                    do: "bg-indigo-600 text-white",
                    else: "text-gray-700 hover:bg-gray-50"
                  )
                ]}
              >
                Yearly <span class="ml-1 text-indigo-600">(Save 17%)</span>
              </button>
            </div>
          </div>
        </div>

        <div class="mt-8 grid max-w-lg grid-cols-1 gap-y-6 sm:grid-cols-3 sm:gap-y-0 sm:gap-x-8 lg:max-w-4xl lg:grid-cols-3">
          <%= for {tier, tier_plans} <- Enum.sort(@plans) do %>
            <% plan = if @selected_interval == "month", do: tier_plans.monthly, else: tier_plans.yearly %>
            <div class="flex flex-col justify-between rounded-3xl bg-white p-8 ring-1 ring-gray-200 xl:p-10">
              <div>
                <div class="flex items-center justify-between gap-x-4">
                  <h3 class="text-lg font-semibold leading-8 text-gray-900">{plan.name}</h3>
                  <%= if tier == "medium" do %>
                    <p class="rounded-full bg-indigo-600/10 px-2.5 py-1 text-xs font-semibold leading-5 text-indigo-600">
                      Most popular
                    </p>
                  <% end %>
                </div>
                <p class="mt-4 text-sm leading-6 text-gray-600">
                  {plan.description}
                </p>
                <p class="mt-6 flex items-baseline gap-x-1">
                  <span class="text-4xl font-bold tracking-tight text-gray-900">
                    ${div(plan.unit_amount, 100)}
                  </span>
                  <span class="text-sm font-semibold leading-6 text-gray-600">/{plan.interval}</span>
                </p>
                <ul role="list" class="mt-8 space-y-3 text-sm leading-6 text-gray-600">
                  <%= for {feature, value} <- plan.features do %>
                    <li class="flex gap-x-3">
                      <.icon name="hero-check" class="h-6 w-5 flex-none text-indigo-600" />
                      {feature}: {value}
                    </li>
                  <% end %>
                </ul>
              </div>
              <a
                href="#"
                class="mt-8 block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold leading-6 text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600"
                phx-click="select_plan"
                phx-value-plan-id={plan.id}
              >
                Get started today
              </a>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("toggle_interval", %{"interval" => interval}, socket)
      when interval in ["month", "year"] do
    {:noreply, assign(socket, selected_interval: interval)}
  end

  def handle_event("select_plan", %{"plan-id" => plan_id}, socket) do
    # For now, just redirect to sign up if not logged in
    # Later we can add proper subscription flow
    {:noreply, push_navigate(socket, to: ~p"/users/register")}
  end
end
