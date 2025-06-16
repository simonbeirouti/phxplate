defmodule PhxplateWeb.Components.AI.PromptSelector do
  @moduledoc """
  A reusable component for selecting AI prompts.

  This component provides a consistent interface for prompt selection
  across different AI-related pages in the application.
  """
  use Phoenix.Component
  import PhxplateWeb.Components.UI.Select

  @doc """
  Renders a prompt selector dropdown.

  ## Examples

      <.prompt_selector
        available_prompts={@prompts}
        selected_prompt={@selected_prompt_name}
        on_change="prompt_changed"
        class="w-[200px]"
      />
  """
  attr :available_prompts, :list, required: true, doc: "List of available prompts"
  attr :selected_prompt, :string, required: true, doc: "Currently selected prompt name"
  attr :on_change, :string, required: true, doc: "Phoenix event to trigger on prompt change"
  attr :class, :string, default: "w-[200px]", doc: "CSS classes for the select trigger"
  attr :id, :string, default: "prompt-select", doc: "HTML ID for the select element"
  attr :show_default, :boolean, default: true, doc: "Whether to show 'Default System' option"
  attr :show_all_option, :boolean, default: false, doc: "Whether to show 'All Prompts' option"
  attr :all_option_text, :string, default: "All Prompts", doc: "Text for all prompts option"
  attr :all_option_value, :string, default: "all", doc: "Value for all prompts option"
  attr :key, :string, default: nil, doc: "Optional key for forcing re-render"
  attr :side, :string, values: ~w(top bottom), default: "bottom", doc: "The side where the select content opens"

  def prompt_selector(assigns) do
    ~H"""
    <form phx-change={@on_change}>
      <.select :let={select} id={@id} name="prompt_name" value={@selected_prompt} key={@key} side={@side}>
        <.select_trigger builder={select} class={@class} />
        <.select_content builder={select} class={@class}>
          <%= if @show_all_option do %>
            <.select_item builder={select} value={@all_option_value} label={@all_option_text}>
              {@all_option_text}
            </.select_item>
          <% end %>
          <%= if @show_default do %>
            <.select_item builder={select} value="Default System" label="Default System">
              Default System
            </.select_item>
          <% end %>
          <%= for prompt <- @available_prompts do %>
            <.select_item builder={select} value={prompt.name} label={prompt.name}>
              {String.slice(prompt.name, 0, 20)}{if String.length(prompt.name) > 20, do: "..."}
            </.select_item>
          <% end %>
        </.select_content>
      </.select>
    </form>
    """
  end
end
