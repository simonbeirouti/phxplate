defmodule PhxplateWeb.PricingLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Subscriptions
  import PhxplateWeb.Components.Subscription.PlanSelector

  @impl true
  def mount(_params, _session, socket) do
    # Get all plans
    plans = Subscriptions.list_all_plans()

    # Fetch subscription if a user is logged in (assigns.current_user is set by auth hooks)
    current_user = socket.assigns.current_user

    subscription =
      if current_user do
        Subscriptions.get_user_subscription(current_user.id)
      else
        nil
      end

    {:ok,
     assign(socket,
       page_title: "Pricing",
       page_description: "Choose the right plan for you",
       page_image: "https://via.placeholder.com/1200x630",
       page_url: "https://phxplate.com/pricing",
       plans: plans,
       current_subscription: subscription
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

        <.plan_selector
          plans={@plans}
          current_user={@current_user}
          current_subscription={@current_subscription}
        />
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("select_plan", %{"plan-id" => plan_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        # User not logged in: redirect to register with plan_id as URL parameter
        {:noreply, push_navigate(socket, to: ~p"/register?plan_id=#{plan_id}")}

      _user ->
        # User logged in: redirect to billing page to manage subscription
        {:noreply, push_navigate(socket, to: ~p"/dashboard/billing")}
    end
  end
end
