defmodule PhxplateWeb.Components.AI.PromptSelector do
  @moduledoc """
  A reusable component for selecting AI prompts.

  This component provides a consistent interface for prompt selection
  across different AI-related pages in the application.
  """
  use Phoenix.Component
  alias Phxplate.AI
  use SaladUI

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
  attr :label, :string, default: nil, doc: "Optional label for the select"

  def prompt_selector(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <%= if @label do %>
        <.label>{@label}</.label>
      <% end %>
      <form phx-change={@on_change}>
        <.select :let={select} id={@id} name="prompt_name" value={@selected_prompt}>
          <.select_trigger builder={select} class={@class} />
          <.select_content class={@class} builder={select}>
            <.select_item builder={select} value="Default System" label="Default system prompt">
              Default system prompt
            </.select_item>
            <%= for prompt <- @available_prompts do %>
              <.select_item builder={select} value={prompt.name} label={prompt.name}>
                {String.slice(prompt.name, 0, 20)}{if String.length(prompt.name) > 20, do: "..."}
              </.select_item>
            <% end %>
          </.select_content>
        </.select>
      </form>
    </div>
    """
  end
end
