defmodule PhxplateWeb.Components.AI.ModelSelector do
  @moduledoc """
  A reusable component for selecting AI models.

  This component provides a consistent interface for model selection
  across different AI-related pages in the application.
  """
  use Phoenix.Component
  alias Phxplate.AI.Models
  import PhxplateWeb.Components.UI.Select

  @doc """
  Renders a model selector dropdown.

  ## Examples

      <.model_selector
        selected_model={@selected_model}
        on_change="select_model"
        class="w-[140px]"
      />
  """
  attr :selected_model, :string, required: true, doc: "Currently selected model display name"
  attr :on_change, :string, required: true, doc: "Phoenix event to trigger on model change"
  attr :class, :string, default: "w-[140px]", doc: "CSS classes for the select trigger"
  attr :id, :string, default: "model-select", doc: "HTML ID for the select element"

  def model_selector(assigns) do
    assigns = assign(assigns, :available_models, Models.available_models())

    ~H"""
    <div class="flex items-center gap-2">
      <form phx-change={@on_change}>
        <.select :let={select} id={@id} name="model" value={@selected_model}>
          <.select_trigger builder={select} class={@class} />
          <.select_content class={@class} builder={select}>
            <%= for {name, _api_id} <- @available_models do %>
              <.select_item builder={select} value={name} label={name}>
                {name}
              </.select_item>
            <% end %>
          </.select_content>
        </.select>
      </form>
    </div>
    """
  end
end
