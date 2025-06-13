defmodule PhxplateWeb.Dashboard.FeatureRequestLive do
  @moduledoc """
  LiveComponent for submitting feature requests.

  This component provides a form for users to submit feature requests with
  priority and feasibility ratings, along with a description of the requested feature.
  """
  use PhxplateWeb, :live_component
  use SaladUI, except: [input: 1]
  alias Phxplate.FeatureRequests.FeatureRequestController

  def update(assigns, socket) do
    # Get the parent component ID from assigns
    # This is the ID of the dashboard layout component
    parent_id = Map.get(assigns, :parent_id)

    # Only initialize form state if it doesn't already exist
    # This ensures we maintain state across dialog/drawer mode changes
    if socket.assigns[:changeset] do
      {:ok, assign(socket, assigns) |> assign(:parent_id, parent_id)}
    else
      changeset = FeatureRequestController.new_changeset()

      socket =
        socket
        |> assign(assigns)
        |> assign(:parent_id, parent_id)
        |> assign(:changeset, changeset)
        |> assign(:form, to_form(changeset))
        |> assign(:priority_rating, nil)
        |> assign(:feasibility_rating, nil)
        |> assign(:request_type, nil)
        # Only show errors after submission attempt
        |> assign(:show_errors, false)
        # Track form validity for button state
        |> assign(:form_valid, false)

      {:ok, socket}
    end
  end

  def render(assigns) do
    ~H"""
    <div class="h-full flex flex-col p-1">
      <div class="flex-1 overflow-y-auto">
        <.form for={@form} phx-submit="submit" phx-change="validate" phx-target={@myself}>
          <div class="space-y-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Request Type
              </label>
              <div class="mb-2 w-full">
                <.toggle_group
                  :let={builder}
                  name="feature_request[feasibility_rating]"
                  size="sm"
                  variant="outline"
                  value={(@request_type && to_string(@request_type)) || nil}
                  phx-change="request_type_changed"
                  phx-target={@myself}
                  class="w-full flex justify-between"
                >
                  <.toggle_group_item
                    value="1"
                    builder={builder}
                    aria-label="Feature Request"
                    class="flex-1"
                  >
                    Feature Request
                  </.toggle_group_item>
                  <.toggle_group_item value="2" builder={builder} aria-label="Feedback" class="flex-1">
                    Feedback
                  </.toggle_group_item>
                </.toggle_group>
              </div>
              <%= if @show_errors do %>
                <.error :for={{msg, _opts} <- @form[:feasibility_rating].errors}>
                  {msg}
                </.error>
              <% end %>
            </div>

            <div>
              <label class="block text-sm font-medium text-gray-700 mb-2">
                Priority Rating (1-10)
              </label>
              <div class="mb-2 w-full">
                <.toggle_group
                  :let={builder}
                  name="feature_request[priority_rating]"
                  size="sm"
                  variant="outline"
                  value={(@priority_rating && to_string(@priority_rating)) || nil}
                  phx-change="priority_changed"
                  phx-target={@myself}
                  class="w-full flex justify-between"
                >
                  <%= for i <- 1..10 do %>
                    <.toggle_group_item
                      value={to_string(i)}
                      builder={builder}
                      aria-label={"Priority #{i} - #{priority_label(i)}"}
                      class="flex-1 px-0"
                    >
                      {i}
                    </.toggle_group_item>
                  <% end %>
                </.toggle_group>
              </div>
              <%= if @show_errors do %>
                <.error :for={{msg, _opts} <- @form[:priority_rating].errors}>
                  {msg}
                </.error>
              <% end %>
            </div>

            <div>
              <label for="feature_description" class="block text-sm font-medium text-gray-700 mb-2">
                Feature Description
              </label>
              <PhxplateWeb.CoreComponents.input
                field={@form[:feature_description]}
                type="textarea"
                placeholder="Describe your feature request in detail (minimum 20 characters)..."
                rows={6}
              />
              <%= if @show_errors do %>
                <.error :for={{msg, _opts} <- @form[:feature_description].errors}>
                  {msg}
                </.error>
              <% end %>
            </div>

            <.button
              type="submit"
              class="w-full"
              phx-disable-with="Submitting..."
              disabled={!@form_valid}
            >
              Submit Feature Request
            </.button>
          </div>
        </.form>
      </div>
    </div>
    """
  end

  # Helper to safely extract integer params
  defp get_integer_param(params, key) do
    case params[key] do
      nil -> nil
      "" -> nil
      val when is_binary(val) -> String.to_integer(val)
      val when is_integer(val) -> val
    end
  end

  def handle_event("validate", %{"feature_request" => params}, socket) do
    # Extract values for validation
    priority = get_integer_param(params, "priority_rating")
    request_type = get_integer_param(params, "feasibility_rating")
    feature_description = params["feature_description"]

    # Check if form is valid for button state using the controller
    form_valid = FeatureRequestController.form_valid?(priority, request_type, feature_description)

    # Update socket assigns for UI state
    socket =
      socket
      |> assign(:priority_rating, priority)
      |> assign(:request_type, request_type)
      |> assign(:feasibility_rating, request_type)
      |> assign(:form_valid, form_valid)

    {:noreply, socket}
  end

  def handle_event("priority_changed", %{"value" => value}, socket) do
    priority_rating = if value == "", do: nil, else: String.to_integer(value)

    # Update both the socket assign and the form changeset
    socket = assign(socket, :priority_rating, priority_rating)

    # Use the controller to validate the changeset
    changeset = FeatureRequestController.validate_feature_request(%{"priority_rating" => priority_rating})

    {:noreply, assign(socket, changeset: changeset, form: to_form(changeset))}
  end

  def handle_event("request_type_changed", %{"value" => value}, socket) do
    request_type = if value == "", do: nil, else: String.to_integer(value)
    # Update both request_type and feasibility_rating (they're the same field)
    socket =
      socket
      |> assign(:request_type, request_type)
      |> assign(:feasibility_rating, request_type)

    # Use the controller to validate the changeset
    changeset = FeatureRequestController.validate_feature_request(%{"feasibility_rating" => request_type})

    {:noreply, assign(socket, changeset: changeset, form: to_form(changeset))}
  end

  def handle_event("submit", %{"feature_request" => params}, socket) do
    # Add the current user's ID to the params if available
    params =
      if socket.assigns.current_user do
        Map.put(params, "user_id", socket.assigns.current_user.id)
      else
        params
      end

    # Always show errors on submit attempt
    socket = assign(socket, :show_errors, true)

    # Use the controller to create the feature request
    case FeatureRequestController.create_feature_request(params) do
      {:ok, _feature_request} ->
        # Use push_event to send a message to the parent LiveView
        _parent_id = socket.assigns.parent_id

        # Send message to the parent LiveView using push_event to a specific target
        # This will trigger the handle_event in the dashboard layout component
        socket = push_event(socket, "feature_request_success", %{message: "Feature request submitted successfully!"})

        # Reset the form in the component using the controller
        changeset = FeatureRequestController.new_changeset()

        socket =
          socket
          |> assign(:changeset, changeset)
          |> assign(:form, to_form(changeset))
          |> assign(:priority_rating, nil)
          |> assign(:feasibility_rating, nil)
          |> assign(:request_type, nil)
          |> assign(:show_errors, false)
          |> assign(:form_valid, false)

        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        # Keep dialog open and show validation errors
        _parent_id = socket.assigns.parent_id

        # Send error message to the parent LiveView using push_event
        socket = push_event(socket, "feature_request_error", %{message: "Please fix the errors in the form."})

        socket = socket |> assign(changeset: changeset, form: to_form(changeset))

        {:noreply, socket}
    end
  end

  # Helper functions for priority labels

  # Helper functions for rating labels
  defp priority_label(1), do: "Very Low"
  defp priority_label(2), do: "Low"
  defp priority_label(3), do: "Somewhat Low"
  defp priority_label(4), do: "Below Average"
  defp priority_label(5), do: "Average"
  defp priority_label(6), do: "Above Average"
  defp priority_label(7), do: "Somewhat High"
  defp priority_label(8), do: "High"
  defp priority_label(9), do: "Very High"
  defp priority_label(10), do: "Critical"
end
