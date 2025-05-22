defmodule PhxplateWeb.PricingLive do
  @moduledoc """
  LiveView for displaying subscription plans and pricing information.

  This view lists available subscription plans for users to choose from, displaying
  pricing information and features for each plan. It handles plan selection differently
  based on authentication status - redirecting unauthenticated users to registration
  and authenticated users to checkout. The view fetches the current user's subscription
  status to highlight their current plan.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.Subscriptions
  import PhxplateWeb.Components.Subscription.PlanSelector
  alias PhxplateWeb.PageMeta

  @doc """
  Initializes the LiveView with available plans and user subscription info.

  Fetches all subscription plans from the database and checks if the current user
  has an active subscription. Sets page metadata with title and description.
  """
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

  @doc """
  Renders the pricing page with plan selection component.

  Displays a heading and description followed by the plan selection component
  which shows all available plans with their features and pricing.
  """
  @impl true
  def render(assigns) do
    ~H"""
    <.header_section title="Pricing" subtitle="Choose the right plan for you" />
    <div class="mx-auto max-w-7xl mt-12 mb-24">
      <.plan_selector
        plans={@plans}
        current_user={@current_user}
        current_subscription={@current_subscription}
        loading={@loading}
      />
    </div>
    <.cta />
    """
  end

  @doc """
  Handles plan selection events from the user.

  If the user is not authenticated, redirects them to the registration page
  with the selected plan ID as a parameter. If the user is authenticated,
  initiates the subscription change process by redirecting to Stripe checkout.
  """
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
