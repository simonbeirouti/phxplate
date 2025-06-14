defmodule PhxplateWeb.Components.AI.EvalSelector do
  @moduledoc """
  A reusable component for selecting AI evaluations.

  This component provides a consistent interface for evaluation selection
  across different AI-related pages in the application.
  """
  use Phoenix.Component
  use SaladUI

  @doc """
  Renders an evaluation selector dropdown.

  ## Examples

      <.eval_selector
        available_evals={@evals}
        selected_eval={@selected_eval}
        on_change="eval_changed"
        class="w-[200px]"
      />
  """
  attr :available_evals, :list, required: true, doc: "List of available evaluations"
  attr :selected_eval, :string, required: true, doc: "Currently selected evaluation name"
  attr :on_change, :string, required: true, doc: "Phoenix event to trigger on evaluation change"
  attr :class, :string, default: "w-[200px]", doc: "CSS classes for the select trigger"
  attr :id, :string, default: "eval-select", doc: "HTML ID for the select element"
  attr :label, :string, default: nil, doc: "Optional label for the select"
  attr :show_default, :boolean, default: true, doc: "Whether to show 'No Eval Selected' option"
  attr :show_all_option, :boolean, default: false, doc: "Whether to show 'All Evaluations' option"
  attr :all_option_text, :string, default: "All Evaluations", doc: "Text for all evaluations option"
  attr :all_option_value, :string, default: "all", doc: "Value for all evaluations option"

  def eval_selector(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <%= if @label do %>
        <.label>{@label}</.label>
      <% end %>
      <form phx-change={@on_change}>
        <.select :let={select} id={@id} name="eval" value={@selected_eval}>
          <.select_trigger builder={select} class={@class} />
          <.select_content class={@class} builder={select}>
            <%= if @show_all_option do %>
              <.select_item builder={select} value={@all_option_value} label={@all_option_text}>
                {@all_option_text}
              </.select_item>
            <% end %>
            <%= if @show_default do %>
              <.select_item builder={select} value="No Eval Selected" label="No evaluation selected">
                No evaluation selected
              </.select_item>
            <% end %>
            <%= for eval <- @available_evals do %>
              <.select_item builder={select} value={eval.name} label={eval.name}>
                {String.slice(eval.name, 0, 20)}{if String.length(eval.name) > 20, do: "..."}
              </.select_item>
            <% end %>
          </.select_content>
        </.select>
      </form>
    </div>
    """
  end
end
