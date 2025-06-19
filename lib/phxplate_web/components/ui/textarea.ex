defmodule PhxplateWeb.Components.UI.Textarea do
  @moduledoc false
  use PhxplateWeb.Component

  import PhxplateWeb.Components.UI.Label

  @doc """
  Displays a form textarea

  ## Example

  ```heex
      <.textarea field={f[:description]} placeholder="Type your message here" />
  ```


  """
  attr :id, :any, default: nil
  attr :name, :string, default: nil
  attr :label, :string, default: nil
  attr :value, :string
  attr :placeholder, :string, default: nil

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:description]"

  attr :class, :string, default: nil
  attr :rest, :global,
    include: ~w(cols disabled form maxlength minlength placeholder readonly required rows wrap)

  def textarea(assigns) do
    assigns = prepare_assign(assigns)

    rest =
      Map.merge(assigns.rest, Map.take(assigns, [:id, :name, :placeholder]))

    assigns = assign(assigns, :rest, rest)

    ~H"""
    <div class="space-y-2">
      <.label for={@id} class="block text-sm font-medium text-gray-700 mb-1">{@label}</.label>
      <textarea
        class={
          classes([
            "min-h-[80px] flex w-full rounded-md border border-input bg-background px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
            @class
          ])
        }
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", assigns[:value]) %></textarea>
    </div>
    """
  end
end
