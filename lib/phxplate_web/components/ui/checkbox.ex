defmodule PhxplateWeb.Components.UI.Checkbox do
  @moduledoc false
  use PhxplateWeb.Component
  import PhxplateWeb.Components.UI.Label


  @doc """
  Implement checkbox input component with label support

  ## Examples:
      <.checkbox class="!border-destructive" name="agree" value={true} label="I agree" />
      <.checkbox field={@form[:remember_me]} label="Remember me" />
  """
  attr :name, :any, default: nil
  attr :value, :any, default: nil
  attr :"default-value", :any, values: [true, false, "true", "false"], default: false
  attr :field, Phoenix.HTML.FormField
  attr :class, :string, default: nil
  attr :label, :string, default: nil
  attr :id, :string, default: nil
  attr :rest, :global

  def checkbox(assigns) do
    assigns = prepare_assign(assigns)

    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns.value)
      end)

    assigns =
      assign_new(assigns, :id, fn ->
        assigns[:id] || "checkbox-#{System.unique_integer([:positive])}"
      end)

    ~H"""
    <div class="flex items-center space-x-2">
      <input type="hidden" name={@name} value="false" />
      <input
        type="checkbox"
        id={@id}
        class={
          classes([
            # Base styles that work with @tailwindcss/forms
            "h-4 w-4 rounded border-border text-primary bg-background",
            # Focus states
            "focus:ring-2 focus:ring-ring focus:ring-offset-2",
            # Make sure checked state is immediate
            "checked:bg-primary checked:border-primary",
            # Smooth transitions
            "transition-colors duration-200",
            # Ensure proper cursor
            "cursor-pointer",
            @class
          ])
        }
        name={@name}
        value="true"
        checked={@checked}
        {@rest}
      />
      <.label :if={@label} for={@id} class="ml-2 text-sm font-medium text-foreground cursor-pointer select-none">
        {@label}
      </.label>
    </div>
    """
  end
end
