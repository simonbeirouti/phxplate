defmodule PhxplateWeb.Components.UI.Collapsible do
  @moduledoc """
  Collapsible component for creating expandable/collapsible content areas.

  This component provides functionality similar to accordion but for standalone
  collapsible sections. Used primarily in sidebar navigation.
  """
  use PhxplateWeb.Component

  alias Phoenix.LiveView.JS

  @doc """
  Render collapsible container
  """
  attr :class, :string, default: nil
  slot :inner_block, required: true

  def collapsible(assigns) do
    ~H"""
    <div class={classes(["", @class])}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Render collapsible trigger button

  This component is designed to be used with the `as_child` helper to wrap
  other components and make them collapsible triggers.
  """
  attr :class, :string, default: nil
  attr :as_tag, :any, default: "button"
  attr :target, :string, default: nil
  slot :inner_block, required: true
  attr :rest, :global

  def collapsible_trigger(assigns) do
    # Generate a unique ID for the collapsible content if target not provided
    target_id = assigns[:target] || "collapsible-#{:rand.uniform(100000)}"
    assigns = assign(assigns, :target_id, target_id)

    ~H"""
    <.dynamic
      tag={@as_tag}
      class={classes(["collapsible-trigger group/collapsible", @class])}
      data-state="closed"
      phx-click={toggle_collapsible(@target_id)}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.dynamic>
    """
  end

  @doc """
  Render collapsible content area
  """
  attr :class, :string, default: nil
  attr :id, :string, required: true
  slot :inner_block, required: true

  def collapsible_content(assigns) do
    ~H"""
    <div
      id={@id}
      class={classes(["collapsible-content hidden", @class])}
      data-state="closed"
    >
      {render_slot(@inner_block)}
    </div>
    """
  end

  # JavaScript for toggling collapsible state
  defp toggle_collapsible(target_id) do
    JS.toggle(to: "##{target_id}")
    |> JS.toggle_attribute({"data-state", "closed", "open"}, to: ".collapsible-trigger")
  end
end
