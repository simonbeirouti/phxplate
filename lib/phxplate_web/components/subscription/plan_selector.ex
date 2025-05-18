defmodule PhxplateWeb.Components.Subscription.PlanSelector do
  @moduledoc """
  Provides components for subscription plan selection and display.

  This module contains components for displaying subscription plans with different
  pricing intervals (monthly/yearly), highlighting popular plans, and showing
  plan features. It handles the display logic for current subscriptions and
  enables users to select new plans.
  """
  use PhxplateWeb, :html

  alias Phxplate.Subscriptions.Plan

  @doc """
  Renders a reusable plan selector component with interval tabs.

  Displays a tabbed interface for selecting between monthly and yearly billing
  intervals, showing appropriate plan cards for each interval.

  ## Examples

      <.plan_selector plans={@plans} current_user={@current_user} current_subscription={@current_subscription} target={@myself} />
  """
  attr :plans, :map, required: true, doc: "Map of plans returned by list_all_plans()."
  attr :current_user, :any, default: nil, doc: "The currently logged-in user, if any."
  attr :current_subscription, :any, default: nil, doc: "The user's current subscription, if any."
  attr :target, :any, default: nil, doc: "The target for phx-target, if any."
  attr :loading, :boolean, default: false, doc: "Whether the plan selection is loading."

  def plan_selector(assigns) do
    ~H"""
    <div>
      <.tabs :let={builder} id="plan-interval-tabs" default="monthly" class="mt-4">
        <.tabs_list class="grid w-2/3 mx-auto grid-cols-2 mb-4">
          <.tabs_trigger builder={builder} value="monthly">Monthly</.tabs_trigger>
          <.tabs_trigger builder={builder} value="yearly">Yearly</.tabs_trigger>
        </.tabs_list>

        <.tabs_content value="monthly">
          <div class="space-y-4 p-4 mt-8">
            <div class="grid lg:grid-cols-3 gap-3 max-w-6xl mx-auto">
              <.plan_card
                :for={plan <- filter_plans(@plans, "month")}
                plan={plan}
                is_popular={plan.metadata["tier"] == "medium"}
                current_user={@current_user}
                current_subscription={@current_subscription}
                target={@target}
                loading={@loading}
              />
            </div>
          </div>
        </.tabs_content>

        <.tabs_content value="yearly">
          <div class="space-y-4 p-4 mt-8">
            <div class="grid lg:grid-cols-3 gap-3 max-w-6xl mx-auto">
              <.plan_card
                :for={plan <- filter_plans(@plans, "year")}
                plan={plan}
                is_popular={plan.metadata["tier"] == "medium"}
                current_user={@current_user}
                current_subscription={@current_subscription}
                target={@target}
                loading={@loading}
              />
            </div>
          </div>
        </.tabs_content>
      </.tabs>
    </div>
    """
  end

  @doc """
  Renders a single plan card with details and selection button.

  Displays plan information including name, price, features, and a button to
  select the plan. Highlights the card if it's marked as popular and shows
  a "Current Plan" indicator if applicable.
  """
  attr :plan, Plan, required: true
  attr :is_popular, :boolean, default: false
  attr :current_user, :any, default: nil
  attr :current_subscription, :any, default: nil
  attr :target, :any, default: nil
  attr :loading, :boolean, default: false

  def plan_card(assigns) do
    ~H"""
    <.card class={"relative rounded-sm" <> if(@is_popular, do: " border-2 border-primary/50 lg:scale-110", else: "")}>
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
          <.button
            phx-click="select_plan"
            phx-value-plan-id={@plan.id}
            phx-target={@target}
            class="w-full"
            disabled={@loading}
          >
            <%= if @loading do %>
              <div class="inline-block animate-spin h-4 w-4 mr-2 border-2 border-white rounded-full border-t-transparent" />
              Processing...
            <% else %>
              Select Plan
            <% end %>
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
