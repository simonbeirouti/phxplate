defmodule PhxplateWeb.Components.UI.DialogDrawerWrapper do
  @moduledoc """
  Renders a dialog or drawer based on the given mode.

  ## Assigns
    - id: DOM id for the wrapper
    - show: boolean, whether to show the dialog/drawer
    - mode: "dialog" or "drawer"
    - on_cancel: JS command for closing
    - hook: optional phx-hook name
    - myself: optional target for phx-target attribute
    - name: title string
    - description: description string
    - inner_block: the content to render inside
  """

  use PhxplateWeb.Component
  use SaladUI
  import PhxplateWeb.Components.UI.Drawer

  attr :id, :string, required: true
  attr :show, :boolean, required: true
  attr :mode, :string, required: true
  attr :on_cancel, :any, required: true
  attr :hook, :string, default: nil
  attr :myself, :any, default: nil
  attr :name, :string, required: true
  attr :description, :string, required: true
  slot :inner_block, required: true

  def dialog_drawer_wrapper(assigns) do
    ~H"""
    <div id={@id} phx-hook={@hook} phx-target={@myself}>
      <%= if @show do %>
        <%= if @mode == "dialog" do %>
          <.dialog id={"#{@id}-dialog"} show={@show} on_cancel={@on_cancel}>
            <.dialog_header>
              <.dialog_title>{@name}</.dialog_title>
              <.dialog_description>{@description}</.dialog_description>
            </.dialog_header>
            {render_slot(@inner_block)}
          </.dialog>
        <% else %>
          <.drawer id={"#{@id}-drawer"} show={@show} on_cancel={@on_cancel}>
            <.drawer_content>
              <.drawer_header>
                <.drawer_title>{@name}</.drawer_title>
                <.drawer_description>{@description}</.drawer_description>
              </.drawer_header>
              {render_slot(@inner_block)}
            </.drawer_content>
          </.drawer>
        <% end %>
      <% end %>
    </div>
    """
  end
end
