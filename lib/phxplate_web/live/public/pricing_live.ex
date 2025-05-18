defmodule PhxplateWeb.PricingLive do
  use PhxplateWeb, :live_view
  alias Phxplate.Subscriptions
  import PhxplateWeb.Components.Subscription.PlanSelector
  alias PhxplateWeb.PageMeta

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
     socket
     |> PageMeta.assign_metadata(
       title: "Pricing",
       description: "Choose the right plan for you",
       url: "/pricing"
     )
     |> assign(
       plans: plans,
       current_subscription: subscription,
       loading: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="py-24 sm:py-32">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <div class="text-center mb-12">
          <h1 class="text-4xl font-bold text-gray-900">Pricing</h1>
          <p class="mt-4 text-lg text-gray-500">Choose the right plan for you</p>
        </div>

        <.plan_selector
          plans={@plans}
          current_user={@current_user}
          current_subscription={@current_subscription}
          loading={@loading}
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

      user ->
        # User logged in: redirect directly to Stripe checkout instead of the dashboard
        socket = assign(socket, :loading, true)
        plan = Subscriptions.get_plan!(plan_id)

        case Subscriptions.change_subscription_plan(user, plan) do
          {:ok, %Stripe.Session{url: checkout_url}} ->
            # Redirect to Stripe checkout
            {:noreply, redirect(socket, external: checkout_url)}

          {:error, _error} ->
            # Handle error
            {:noreply,
             socket
             |> assign(:loading, false)
             |> put_flash(:error, "Failed to process subscription. Please try again later.")}
        end
    end
  end
end
