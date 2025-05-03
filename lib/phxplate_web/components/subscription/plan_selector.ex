defmodule PhxplateWeb.Components.Subscription.PlanSelector do
  use PhxplateWeb, :html

  alias Phxplate.Subscriptions.Plan
  alias PhxplateWeb.Components.UI.Tabs
  import Tabs

  @doc """
  Renders a reusable plan selector component.

  ## Examples

      <.plan_selector plans={@plans} current_user={@current_user} current_subscription={@current_subscription} />
  """
  attr :plans, :map, required: true, doc: "Map of plans returned by list_all_plans()."
  attr :current_user, :any, default: nil, doc: "The currently logged-in user, if any."
  attr :current_subscription, :any, default: nil, doc: "The user's current subscription, if any."

  def plan_selector(assigns) do
    ~H"""
    <div>
      <.tabs :let={builder} id="plan-interval-tabs" default="monthly" class="mt-8">
        <.tabs_list class="grid w-1/3 mx-auto grid-cols-2 mb-4">
          <.tabs_trigger builder={builder} value="monthly">Monthly</.tabs_trigger>
          <.tabs_trigger builder={builder} value="yearly">Yearly</.tabs_trigger>
        </.tabs_list>

        <.tabs_content value="monthly">
          <div class="space-y-4 p-4 mt-16">
            <div class="grid lg:grid-cols-3 gap-3 max-w-6xl mx-auto">
              <.plan_card
                :for={plan <- filter_plans(@plans, "month")}
                plan={plan}
                is_popular={plan.metadata["tier"] == "medium"}
                current_user={@current_user}
                current_subscription={@current_subscription}
              />
            </div>
          </div>
        </.tabs_content>

        <.tabs_content value="yearly">
          <div class="space-y-4 p-4 mt-16">
            <div class="grid lg:grid-cols-3 gap-3 max-w-6xl mx-auto">
              <.plan_card
                :for={plan <- filter_plans(@plans, "year")}
                plan={plan}
                is_popular={plan.metadata["tier"] == "medium"}
                current_user={@current_user}
                current_subscription={@current_subscription}
              />
            </div>
          </div>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  @doc """
  Renders a single plan card.
  """
  attr :plan, Plan, required: true
  attr :is_popular, :boolean, default: false
  attr :current_user, :any, default: nil
  attr :current_subscription, :any, default: nil

  def plan_card(assigns) do
    ~H"""
    <.card class={["relative rounded-sm", @is_popular && "border-2 border-primary/50 lg:scale-110"]}>
      <%= if @is_popular do %>
        <div class="absolute -top-3 right-4 bg-primary text-primary-foreground px-3 py-1 rounded-full text-sm">
          Most Popular
        </div>
      <% end %>
      <.card_header>
        <.card_title class="text-xl">{@plan.name}</.card_title>
        <.card_description class="text-3xl font-bold">
          {format_price(@plan)}
          <span class="ml-1 text-sm font-normal">/ {@plan.interval}</span>
        </.card_description>
        <.card_description class="mt-2">
          {@plan.description}
        </.card_description>
      </.card_header>
      <.card_content>
        <ul class="space-y-4">
          <%= for {_feature_name, feature_value} <- @plan.features do %>
            <li class="flex items-start gap-2">
              <span class="text-primary">✓</span>
              {feature_value}
            </li>
          <% end %>
        </ul>
      </.card_content>
      <.card_footer>
        <%= if @current_user && @current_subscription && @current_subscription.plan_id == @plan.id do %>
          <.button class="w-full" disabled>Current Plan</.button>
        <% else %>
          <.button phx-click="select_plan" phx-value-plan-id={@plan.id} class="w-full">
            Select Plan
          </.button>
        <% end %>
      </.card_footer>
    </.card>
    """
  end

  defp filter_plans(plans_map, interval) when interval == "month" do
    plans_map
    |> Map.values()
    |> Enum.map(& &1.monthly)
    |> Enum.sort_by(& &1.unit_amount)
  end

  defp filter_plans(plans_map, interval) when interval == "year" do
    plans_map
    |> Map.values()
    |> Enum.map(& &1.yearly)
    |> Enum.sort_by(& &1.unit_amount)
  end

  defp format_price(%Plan{unit_amount: amount, currency: currency}) when is_integer(amount) do
    formatted_amount = amount / 100

    currency_symbol =
      case currency do
        "usd" -> "$"
        _ -> String.upcase(currency) <> " "
      end

    "#{currency_symbol}#{formatted_amount}"
  end

  defp format_price(%Plan{unit_amount: amount}), do: to_string(amount)
end
