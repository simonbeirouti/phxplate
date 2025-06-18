defmodule PhxplateWeb.Components.Subscription.SinglePurchaseSelector do
  @moduledoc """
  Component for displaying and selecting single purchase products.

  This component handles the display of one-time purchase products
  separately from subscription plans, providing a cleaner separation
  of concerns.
  """
  use PhxplateWeb, :html

  alias Phxplate.Subscriptions.Plan

  @doc """
  Renders a grid of single purchase products.

  Displays available one-time purchase products in a grid layout
  with product details and purchase buttons.

  ## Examples

      <.single_purchase_selector products={@single_purchase_plans} current_user={@current_user} target={@myself} />
  """
  attr :products, :list, required: true, doc: "List of single purchase products."
  attr :current_user, :any, default: nil, doc: "The currently logged-in user, if any."
  attr :target, :any, default: nil, doc: "The target for phx-target, if any."
  attr :loading, :boolean, default: false, doc: "Whether the purchase is loading."
  attr :title, :string, default: "One-Time Purchases", doc: "Title for the section."

  attr :description, :string,
    default: "Purchase products and services without a subscription.",
    doc: "Description for the section."

  attr :class, :string, default: "", doc: "Additional CSS classes."

  def single_purchase_selector(assigns) do
    ~H"""
    <div class={["space-y-6", @class]}>
      <div class="text-center">
        <h2 class="text-2xl font-bold text-gray-900">{@title}</h2>
        <p class="mt-2 text-gray-600">{@description}</p>
      </div>

      <%= if Enum.empty?(@products) do %>
        <div class="text-center py-12">
          <div class="bg-gray-50 border border-gray-200 rounded-lg p-8">
            <Lucideicons.shopping_cart class="h-12 w-12 mx-auto text-gray-400 mb-4" />
            <h3 class="text-lg font-medium text-gray-900 mb-2">No Products Available</h3>
            <p class="text-gray-600">
              There are currently no one-time purchase products available.
              Check back later for new offerings.
            </p>
          </div>
        </div>
      <% else %>
        <div class="grid lg:grid-cols-3 gap-6 max-w-6xl mx-auto">
          <.single_purchase_card
            :for={product <- @products}
            product={product}
            current_user={@current_user}
            target={@target}
            loading={@loading}
          />
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a single purchase product card.

  Displays product information including name, price, features, and a button to
  purchase the product. Used for one-time purchases like templates, services, etc.
  """
  attr :product, Plan, required: true
  attr :current_user, :any, default: nil
  attr :target, :any, default: nil
  attr :loading, :boolean, default: false

  def single_purchase_card(assigns) do
    ~H"""
    <.card class="relative">
      <.card_header>
        <.card_title class="text-xl">{@product.name}</.card_title>
        <.card_description class="text-3xl font-bold text-primary">
          {format_price(@product)}
          <span class="ml-1 text-sm font-normal text-gray-500">one-time</span>
        </.card_description>
        <.card_description class="mt-2 text-gray-600">
          {@product.description}
        </.card_description>
      </.card_header>
      <.card_content>
        <%= if @product.features && map_size(@product.features) > 0 do %>
          <ul class="space-y-3">
            <%= for feature_key <- get_ordered_features(@product) do %>
              <li class="flex items-start gap-2">
                <Lucideicons.check class="h-4 w-4 text-green-500 mt-1 flex-shrink-0" />
                <span class="text-sm text-gray-700">
                  {Map.get(@product.features, feature_key, "")}
                </span>
              </li>
            <% end %>
          </ul>
        <% end %>
      </.card_content>
      <.card_footer>
        <.button
          phx-click="purchase_product"
          phx-value-product-id={@product.id}
          phx-target={@target}
          class="w-full"
          disabled={@loading}
        >
          <%= if @loading do %>
            <div class="inline-block animate-spin h-4 w-4 mr-2 border-2 border-white rounded-full border-t-transparent" />
            Processing...
          <% else %>
            Purchase Now
          <% end %>
        </.button>
      </.card_footer>
    </.card>
    """
  end

  defp get_ordered_features(%Plan{features_order: features_order}) when is_list(features_order) do
    features_order
  end

  defp get_ordered_features(%Plan{features: features}) when is_map(features) do
    Map.keys(features) |> Enum.sort()
  end

  defp get_ordered_features(_), do: []

  defp format_price(%Plan{unit_amount: amount, currency: currency}) when is_integer(amount) do
    formatted_amount = amount / 100

    currency_symbol =
      case currency do
        "usd" -> "$"
        "eur" -> "€"
        _ -> String.upcase(currency) <> " "
      end

    "#{currency_symbol}#{:erlang.float_to_binary(formatted_amount, decimals: 2)}"
  end

  defp format_price(%Plan{unit_amount: amount}), do: to_string(amount)
end
