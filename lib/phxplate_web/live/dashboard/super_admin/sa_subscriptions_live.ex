defmodule PhxplateWeb.Dashboard.SuperAdmin.SubscriptionsLive do
  @moduledoc """
  LiveView for managing subscriptions and plans in the super admin panel.

  This view allows super admins to:
  - View all subscription plans
  - Create new plans
  - Edit existing plans
  - Delete plans
  - View active subscriptions
  - Manage subscription statuses
  - Sync with Stripe
  """
  use PhxplateWeb, :live_view
  import Ecto.Query
  alias Phxplate.Subscriptions
  alias Phxplate.Subscriptions.{Plan, Subscription}
  alias PhxplateWeb.PageMeta
  alias Phxplate.PubSub.DataSync
  import PhxplateWeb.Components.UI.Drawer
  alias PhxplateWeb.Components.UI.TabsNew

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      DataSync.subscribe("subscriptions", "all")
      DataSync.subscribe("plans", "all")
    end

    plans = Subscriptions.list_all_plans()
    subscriptions = list_all_subscriptions()

    {:ok,
     socket
     |> assign(:plans, plans)
     |> assign(:subscriptions, subscriptions)
     |> assign(:active_tab, "monthly")
     |> assign(:current_interval, "monthly")
     |> assign(:show_plan_modal, false)
     |> assign(:show_subscription_modal, false)
     |> assign(:editing_plan, nil)
     |> assign(:editing_subscription, nil)
     |> assign(:selected_item, nil)
     |> assign(:selected_type, nil)
     |> assign(:show_drawer, false)
     |> assign(:editing_mode, false)
     |> assign(:plan_form, to_form(%{}, as: :plan))
     |> assign(:features_order, [])
     |> assign(:loading, false)
     |> assign(:page_title, "Subscription Management")
     |> PageMeta.assign_metadata(
       title: "Subscription Management",
       description: "Manage subscription plans and user subscriptions",
       url: "/dashboard/super_admin/subscriptions"
     )}
  end

  @impl true
  def handle_params(params, url, socket) do
    uri = URI.parse(url)
    socket = Phoenix.Component.update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    tab = Map.get(params, "tab", "monthly")
    {:noreply,
     socket
     |> assign(:active_tab, tab)
     |> assign(:current_interval, tab)}
  end

  @impl true
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply,
     socket
     |> assign(:active_tab, tab)
     |> assign(:current_interval, tab)
     |> assign(:selected_item, nil)
     |> assign(:selected_type, nil)
     |> assign(:show_drawer, false)
     |> push_patch(to: ~p"/dashboard/super_admin/subscriptions?tab=#{tab}")}
  end

    @impl true
  def handle_event("select_plan", %{"id" => plan_id}, socket) do
    plan = get_plan_by_id(plan_id, socket.assigns.plans)

    if plan do
      {:noreply,
       socket
       |> assign(:selected_item, plan)
       |> assign(:selected_type, :plan)
       |> assign(:editing_mode, false)
       |> assign(:show_drawer, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_subscription", %{"id" => subscription_id}, socket) do
    subscription = Enum.find(socket.assigns.subscriptions, &(to_string(&1.id) == subscription_id))

    if subscription do
      {:noreply,
       socket
       |> assign(:selected_item, subscription)
       |> assign(:selected_type, :subscription)
       |> assign(:show_drawer, true)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("close_drawer", _params, socket) do
    {:noreply, assign(socket, :show_drawer, false)}
  end

  @impl true
  def handle_event("start_editing", _params, socket) do
    if socket.assigns.selected_item do
      plan = socket.assigns.selected_item

      # Use existing features_order from database if available, otherwise create from features
      features_order = if plan.features_order && length(plan.features_order) > 0 do
        plan.features_order
      else
        # Fallback to sorted keys if no order is defined
        Map.keys(plan.features || %{}) |> Enum.sort()
      end

      plan_form = to_form(%{
        "name" => plan.name,
        "description" => plan.description || "",
        "unit_amount" => to_string(plan.unit_amount),
        "currency" => plan.currency,
        "interval" => plan.interval,
        "tier" => plan.metadata["tier"] || "",
        "features" => plan.features || %{}
      }, as: :plan)

      {:noreply,
       socket
       |> assign(:editing_mode, true)
       |> assign(:plan_form, plan_form)
       |> assign(:features_order, features_order)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("cancel_editing", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_mode, false)
     |> assign(:features_order, [])}
  end

        @impl true
  def handle_event("save_inline_edit", %{"plan" => plan_params}, socket) do
    if socket.assigns.selected_item do
      plan = socket.assigns.selected_item

      # Debug: log the parameters and order
      IO.inspect(plan_params, label: "Raw plan_params")
      IO.inspect(socket.assigns.features_order, label: "Features order")

      # Process the plan parameters to handle features properly with ordering
      processed_params = process_plan_params_with_order(plan_params, socket.assigns.features_order)

      IO.inspect(processed_params, label: "Processed params")

      case Subscriptions.update_plan(plan, processed_params, socket.assigns.current_user) do
        {:ok, updated_plan} ->
          # Reload all plans to get the updated data structure
          plans = Subscriptions.list_all_plans()

          # Find the updated plan in the new structure
          updated_selected_item = find_plan_in_structure(updated_plan.id, plans)

          {:noreply,
           socket
           |> assign(:plans, plans)
           |> assign(:selected_item, updated_selected_item || updated_plan)
           |> assign(:editing_mode, false)
           |> assign(:features_order, [])
           |> put_flash(:info, "Plan updated successfully")}

        {:error, changeset} ->
          {:noreply,
           socket
           |> assign(:plan_form, to_form(changeset, as: :plan))
           |> put_flash(:error, "Failed to update plan: #{format_changeset_errors(changeset)}")}
      end
    else
      {:noreply, socket}
    end
  end

      @impl true
  def handle_event("add_feature", _params, socket) do
    if socket.assigns.editing_mode do
      current_features = socket.assigns.plan_form.params["features"] || %{}
      current_order = socket.assigns.features_order

      # Generate a unique temporary key for new features
      temp_key = "new_feature_#{System.unique_integer([:positive])}"
      new_features = Map.put(current_features, temp_key, "")
      new_order = current_order ++ [temp_key]

      plan_params = Map.put(socket.assigns.plan_form.params, "features", new_features)
      plan_form = to_form(plan_params, as: :plan)

      {:noreply,
       socket
       |> assign(:plan_form, plan_form)
       |> assign(:features_order, new_order)}
    else
      {:noreply, socket}
    end
  end

    @impl true
  def handle_event("remove_feature", %{"key" => key}, socket) do
    if socket.assigns.editing_mode do
      current_features = socket.assigns.plan_form.params["features"] || %{}
      current_order = socket.assigns.features_order

      new_features = Map.delete(current_features, key)
      new_order = List.delete(current_order, key)

      plan_params = Map.put(socket.assigns.plan_form.params, "features", new_features)
      plan_form = to_form(plan_params, as: :plan)

      {:noreply,
       socket
       |> assign(:plan_form, plan_form)
       |> assign(:features_order, new_order)}
    else
      {:noreply, socket}
    end
  end

    @impl true
  def handle_event("validate_plan", %{"plan" => plan_params}, socket) do
    # Process features to handle dynamic key-value pairs
    processed_params = process_plan_params(plan_params)

    changeset =
      socket.assigns.selected_item
      |> Plan.changeset(processed_params)
      |> Map.put(:action, :validate)

    plan_form = to_form(changeset, as: :plan)

    {:noreply, assign(socket, :plan_form, plan_form)}
  end

  @impl true
  def handle_event("update_feature", %{"index" => index_str, "type" => type, "value" => value}, socket) do
    if socket.assigns.editing_mode do
      index = String.to_integer(index_str)
      current_features = socket.assigns.plan_form.params["features"] || %{}

      # Convert features to list to maintain order
      features_list = Enum.to_list(current_features)

      if index < length(features_list) do
        {old_key, old_value} = Enum.at(features_list, index)

        # Update the specific field
        updated_entry = case type do
          "key" -> {value, old_value}
          "value" -> {old_key, value}
        end

        # Replace at the specific index
        updated_features_list = List.replace_at(features_list, index, updated_entry)
        updated_features = Enum.into(updated_features_list, %{})

        plan_params = Map.put(socket.assigns.plan_form.params, "features", updated_features)
        plan_form = to_form(plan_params, as: :plan)

        {:noreply, assign(socket, :plan_form, plan_form)}
      else
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

        @impl true
  def handle_event("reorder_features", %{"from" => from_index, "to" => to_index}, socket) do
    IO.inspect(%{from: from_index, to: to_index, editing_mode: socket.assigns.editing_mode}, label: "Reorder features event")

    if socket.assigns.editing_mode do
      features_order = socket.assigns.features_order

      IO.inspect(features_order, label: "Current features order")

      from_idx = String.to_integer(from_index)
      to_idx = String.to_integer(to_index)

      if from_idx != to_idx and from_idx < length(features_order) and to_idx < length(features_order) do
        # Move the key from from_idx to to_idx in the order list
        {key, remaining_order} = List.pop_at(features_order, from_idx)
        new_order = List.insert_at(remaining_order, to_idx, key)

        IO.inspect(new_order, label: "New features order")

        {:noreply, assign(socket, :features_order, new_order)}
      else
        IO.inspect("Invalid reorder indices", label: "Reorder error")
        {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("new_plan", _params, socket) do
    # Convert tab name to interval for Stripe
    interval = case socket.assigns.current_interval do
      "monthly" -> "month"
      "yearly" -> "year"
      "one_time" -> "one_time"
      _ -> "month"
    end

    plan_form = to_form(%{
      "name" => "",
      "description" => "",
      "unit_amount" => "",
      "currency" => "usd",
      "interval" => interval,
      "tier" => "",
      "features" => %{}
    }, as: :plan)

    {:noreply,
     socket
     |> assign(:show_plan_modal, true)
     |> assign(:editing_plan, nil)
     |> assign(:plan_form, plan_form)}
  end

  @impl true
  def handle_event("edit_plan", %{"id" => plan_id}, socket) do
    plan = get_plan_by_id(plan_id, socket.assigns.plans)

    if plan do
      plan_form = to_form(%{
        "name" => plan.name,
        "description" => plan.description || "",
        "unit_amount" => to_string(plan.unit_amount),
        "currency" => plan.currency,
        "interval" => plan.interval,
        "tier" => plan.metadata["tier"] || "",
        "features" => plan.features || %{}
      }, as: :plan)

      {:noreply,
       socket
       |> assign(:show_plan_modal, true)
       |> assign(:editing_plan, plan)
       |> assign(:plan_form, plan_form)}
    else
      {:noreply, put_flash(socket, :error, "Plan not found")}
    end
  end

  @impl true
  def handle_event("delete_plan", %{"id" => plan_id}, socket) do
    plan = get_plan_by_id(plan_id, socket.assigns.plans)

    if plan do
      case Subscriptions.delete_plan(plan, socket.assigns.current_user) do
        {:ok, _} ->
          plans = Subscriptions.list_all_plans()
          {:noreply,
           socket
           |> assign(:plans, plans)
           |> put_flash(:info, "Plan deleted successfully")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to delete plan")}
      end
    else
      {:noreply, put_flash(socket, :error, "Plan not found")}
    end
  end

  @impl true
  def handle_event("close_plan_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_plan_modal, false)
     |> assign(:editing_plan, nil)}
  end

  @impl true
  def handle_event("save_plan", %{"plan" => plan_params}, socket) do
    socket = assign(socket, :loading, true)

    case socket.assigns.editing_plan do
      nil ->
        # Create new plan
        normalized_params = normalize_plan_params(plan_params)
        case Subscriptions.create_plan(normalized_params, socket.assigns.current_user) do
          {:ok, _plan} ->
            plans = Subscriptions.list_all_plans()
            {:noreply,
             socket
             |> assign(:plans, plans)
             |> assign(:show_plan_modal, false)
             |> assign(:loading, false)
             |> put_flash(:info, "Plan created successfully")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:plan_form, to_form(changeset, as: :plan))
             |> assign(:loading, false)
             |> put_flash(:error, "Failed to create plan")}
        end

      plan ->
        # Update existing plan
        normalized_params = normalize_plan_params(plan_params)
        case Subscriptions.update_plan(plan, normalized_params, socket.assigns.current_user) do
          {:ok, _plan} ->
            plans = Subscriptions.list_all_plans()
            {:noreply,
             socket
             |> assign(:plans, plans)
             |> assign(:show_plan_modal, false)
             |> assign(:loading, false)
             |> put_flash(:info, "Plan updated successfully")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:plan_form, to_form(changeset, as: :plan))
             |> assign(:loading, false)
             |> put_flash(:error, "Failed to update plan")}
        end
    end
  end

  @impl true
  def handle_event("validate_plan", %{"plan" => plan_params}, socket) do
    changeset =
      %Plan{}
      |> Plan.changeset(normalize_plan_params(plan_params))
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :plan_form, to_form(changeset, as: :plan))}
  end



  @impl true
  def handle_event("update_subscription_status", %{"id" => subscription_id, "status" => status}, socket) do
    subscription = Enum.find(socket.assigns.subscriptions, &(to_string(&1.id) == subscription_id))

    if subscription do
      status_atom = String.to_atom(status)
      case Subscriptions.admin_update_subscription_status(subscription, status_atom, socket.assigns.current_user) do
        {:ok, _updated_subscription} ->
          subscriptions = list_all_subscriptions()
          {:noreply,
           socket
           |> assign(:subscriptions, subscriptions)
           |> put_flash(:info, "Subscription status updated successfully")}

        {:error, _reason} ->
          {:noreply, put_flash(socket, :error, "Failed to update subscription status")}
      end
    else
      {:noreply, put_flash(socket, :error, "Subscription not found")}
    end
  end

  @impl true
  def handle_info({:created, %{type: :plan}}, socket) do
    plans = Subscriptions.list_all_plans()
    {:noreply, assign(socket, :plans, plans)}
  end

  def handle_info({:updated, %{type: :plan}}, socket) do
    plans = Subscriptions.list_all_plans()
    {:noreply, assign(socket, :plans, plans)}
  end

  def handle_info({:deleted, %{type: :plan}}, socket) do
    plans = Subscriptions.list_all_plans()
    {:noreply,
     socket
     |> assign(:plans, plans)
     |> assign(:selected_item, nil)
     |> assign(:selected_type, nil)
     |> assign(:show_drawer, false)}
  end

  # Ignore other PubSub messages
  def handle_info(_msg, socket), do: {:noreply, socket}

  # Helper functions

  defp list_all_subscriptions do
    Phxplate.Repo.all(
      from s in Subscription,
      join: u in assoc(s, :user),
      join: p in assoc(s, :plan),
      preload: [user: u, plan: p],
      order_by: [desc: s.inserted_at]
    )
  end

  defp get_plan_by_id(plan_id, plans) do
    plan_id = String.to_integer(plan_id)

    Enum.find_value(plans, fn {_tier, tier_plans} ->
      Enum.find([tier_plans.monthly, tier_plans.yearly], &(&1 && &1.id == plan_id))
    end)
  end

  defp normalize_plan_params(params) do
    # Determine product type based on interval
    product_type = if params["interval"] == "one_time", do: :single_purchase, else: :subscription

    # Set interval to nil for single purchase products
    interval = if product_type == :single_purchase, do: nil, else: params["interval"]

    %{
      name: params["name"],
      description: params["description"],
      unit_amount: String.to_integer(params["unit_amount"]),
      currency: params["currency"],
      interval: interval,
      product_type: product_type,
      metadata: %{"tier" => params["tier"]},
      features: parse_features(params["features"] || %{}),
      features_order: params["features_order"] || []
    }
  end

  defp parse_features(features) when is_map(features), do: features
  defp parse_features(_), do: %{}



  defp format_currency(amount) when is_integer(amount) do
    "$#{Float.round(amount / 100, 2)}"
  end

  defp format_currency(_), do: "$0.00"

  # defp format_features(features) when is_map(features) do
  #   features
  #   |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
  #   |> Enum.join(", ")
  # end

  # defp format_features(_), do: "None"

  # Helper function to get plans by interval
  defp get_plans_by_interval(plans, interval) do
    plans
    |> Enum.flat_map(fn {_tier, tier_plans} ->
      case interval do
        "monthly" -> if tier_plans.monthly, do: [tier_plans.monthly], else: []
        "yearly" -> if tier_plans.yearly, do: [tier_plans.yearly], else: []
        "one_time" -> [] # For future one-time purchases
        # Handle Stripe interval names too
        "month" -> if tier_plans.monthly, do: [tier_plans.monthly], else: []
        "year" -> if tier_plans.yearly, do: [tier_plans.yearly], else: []
      end
    end)
  end

    # Details rendering function
  defp render_details(assigns) do
    context = assigns[:context] || "desktop"
    assigns = assign(assigns, :context, context)

    ~H"""
    <%= if @selected_type == :plan do %>
      <div class="space-y-4">
        <%= if @editing_mode do %>
          <.form
            for={@plan_form}
            phx-change="validate_plan"
            phx-submit="save_inline_edit"
            class="space-y-4"
          >
            <div class="grid grid-cols-1 gap-4">
              <.input
                field={@plan_form[:name]}
                type="text"
                label="Name"
                required
              />

              <.input
                field={@plan_form[:description]}
                type="textarea"
                label="Description"
                rows="3"
              />

              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@plan_form[:unit_amount]}
                  type="number"
                  label="Price (cents)"
                  required
                />

                <.input
                  field={@plan_form[:tier]}
                  type="select"
                  label="Tier"
                  options={[
                    {"Small", "small"},
                    {"Medium", "medium"},
                    {"Large", "large"}
                  ]}
                  required
                />
              </div>

              <div class="grid grid-cols-2 gap-4">
                <.input
                  field={@plan_form[:currency]}
                  type="select"
                  label="Currency"
                  options={[{"USD", "usd"}]}
                  required
                />

                <.input
                  field={@plan_form[:interval]}
                  type="select"
                  label="Billing Type"
                  options={[
                    {"Monthly", "month"},
                    {"Yearly", "year"},
                    {"One-time", "one_time"}
                  ]}
                  required
                />
              </div>

              <div>
                <div class="flex justify-between items-center mb-2">
                  <label class="text-sm font-medium text-gray-700">Features</label>
                  <.button
                    type="button"
                    variant="outline"
                    size="sm"
                    phx-click="add_feature"
                  >
                    <Lucideicons.plus class="h-3 w-3 mr-1" />
                    Add Feature
                  </.button>
                </div>

                                <%= if @plan_form.params["features"] && map_size(@plan_form.params["features"]) > 0 do %>
                  <div
                    class="space-y-2"
                    id="features-container"
                    phx-hook="Sortable"
                    data-group="features"
                  >
                    <%= for {key, index} <- Enum.with_index(@features_order) do %>
                      <% value = @plan_form.params["features"][key] || "" %>
                      <div
                        class="flex gap-2 items-center bg-gray-50 p-2 rounded border"
                        id={"feature-#{index}"}
                        data-feature-key={key}
                        data-feature-value={value}
                        data-index={index}
                      >
                        <div class="drag-handle cursor-move text-gray-400 hover:text-gray-600 flex-shrink-0">
                          <Lucideicons.grip_vertical class="h-4 w-4" />
                        </div>

                        <input
                          type="hidden"
                          name={"plan[features_to_remove][]"}
                          value={key}
                          disabled
                        />
                        <input
                          type="text"
                          name={"plan[feature_keys][]"}
                          value={key}
                          placeholder="Feature name"
                          class="flex-1 text-sm border border-gray-300 rounded px-2 py-1"
                          phx-debounce="300"
                          phx-blur="update_feature"
                          phx-value-index={index}
                          phx-value-type="key"
                        />
                        <input
                          type="text"
                          name={"plan[feature_values][]"}
                          value={value}
                          placeholder="Feature value"
                          class="flex-1 text-sm border border-gray-300 rounded px-2 py-1"
                          phx-debounce="300"
                          phx-blur="update_feature"
                          phx-value-index={index}
                          phx-value-type="value"
                        />
                        <.button
                          type="button"
                          variant="outline"
                          size="sm"
                          phx-click="remove_feature"
                          phx-value-key={key}
                        >
                          <Lucideicons.x class="h-3 w-3" />
                        </.button>
                      </div>
                    <% end %>
                  </div>
                <% else %>
                  <p class="text-sm text-gray-500 italic">No features added yet</p>
                <% end %>
              </div>
            </div>

            <div class="border-t pt-4">
              <div class="flex gap-2">
                <.button
                  type="submit"
                  class="flex-1"
                >
                  <Lucideicons.check class="h-3 w-3 mr-1" />
                  Save Changes
                </.button>
                <.button
                  type="button"
                  variant="outline"
                  class="flex-1"
                  phx-click="cancel_editing"
                >
                  <Lucideicons.x class="h-3 w-3 mr-1" />
                  Cancel
                </.button>
              </div>
            </div>
          </.form>
        <% else %>
          <div class="grid grid-cols-1 gap-4">
            <div>
              <h4 class="text-sm font-medium text-gray-500">Name</h4>
              <p class="mt-1 text-lg font-semibold">{@selected_item.name}</p>
            </div>

            <div>
              <h4 class="text-sm font-medium text-gray-500">Description</h4>
              <p class="mt-1">{@selected_item.description || "No description"}</p>
            </div>

            <div class="grid grid-cols-2 gap-4">
              <div>
                <h4 class="text-sm font-medium text-gray-500">Price</h4>
                <p class="mt-1 text-2xl font-bold text-gray-900">
                  {format_currency(@selected_item.unit_amount)}
                </p>
                <p class="text-sm text-gray-500">
                  <%= if @selected_item.interval == "one_time" do %>
                    one-time purchase
                  <% else %>
                    per {@selected_item.interval}
                  <% end %>
                </p>
              </div>

              <div>
                <h4 class="text-sm font-medium text-gray-500">Tier</h4>
                <p class="mt-1 capitalize">{@selected_item.metadata["tier"] || "Unknown"}</p>
              </div>
            </div>

            <div>
              <h4 class="text-sm font-medium text-gray-500">Currency</h4>
              <p class="mt-1 uppercase">{@selected_item.currency}</p>
            </div>

            <%= if @selected_item.features && map_size(@selected_item.features) > 0 do %>
              <div>
                <h4 class="text-sm font-medium text-gray-500">Features</h4>
                <div class="mt-1 space-y-1">
                  <%= for key <- get_ordered_feature_keys(@selected_item) do %>
                    <% value = Map.get(@selected_item.features, key, "") %>
                    <div class="flex justify-between py-1 border-b border-gray-100">
                      <span class="text-sm text-gray-600 capitalize">{key}:</span>
                      <span class="text-sm font-medium">{value}</span>
                    </div>
                  <% end %>
                </div>
              </div>
            <% else %>
              <div>
                <h4 class="text-sm font-medium text-gray-500">Features</h4>
                <p class="mt-1 text-sm text-gray-500 italic">No features defined</p>
              </div>
            <% end %>

            <div class="border-t pt-4">
              <h4 class="text-sm font-medium text-gray-500">Stripe Information</h4>
              <div class="mt-2 space-y-2">
                <div>
                  <span class="text-xs text-gray-500">Product ID:</span>
                  <p class="text-xs font-mono bg-gray-100 p-1 rounded">{@selected_item.stripe_product_id}</p>
                </div>
                <div>
                  <span class="text-xs text-gray-500">Price ID:</span>
                  <p class="text-xs font-mono bg-gray-100 p-1 rounded">{@selected_item.stripe_price_id}</p>
                </div>
              </div>
            </div>

            <div class="border-t pt-4">
              <h4 class="text-sm font-medium text-gray-500">Timestamps</h4>
              <div class="flex justify-between items-center mt-2 text-xs text-gray-500">
                <p>Created: {Calendar.strftime(@selected_item.inserted_at, "%B %d, %Y at %H:%M")}</p>
                <p>Updated: {Calendar.strftime(@selected_item.updated_at, "%B %d, %Y at %H:%M")}</p>
              </div>
            </div>
            <%= if not @editing_mode do %>
              <div class="flex justify-between items-center w-full">
                <div class="flex gap-2 w-full">
                  <.button
                    variant="outline"
                    size="sm"
                    class="w-full"
                    phx-click="start_editing"
                  >
                    <Lucideicons.pencil class="h-3 w-3 mr-1" />
                    Edit
                  </.button>
                  <.button
                    variant="destructive"
                    size="sm"
                    class="w-full"
                    phx-click="delete_plan"
                    phx-value-id={@selected_item.id}
                    data-confirm="Are you sure you want to delete this plan?"
                  >
                    <Lucideicons.trash_2 class="h-3 w-3 mr-1" />
                    Delete
                  </.button>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% else %>
      <p class="text-gray-500">No details available</p>
    <% end %>
    """
  end

  # Plans by interval component
  defp plans_by_interval_tab(assigns) do
    interval_plans = get_plans_by_interval(assigns.plans, assigns.interval)
    assigns = assign(assigns, :interval_plans, interval_plans)

    ~H"""
    <div class="space-y-6">
      <%= if Enum.empty?(@interval_plans) do %>
        <div class="text-center py-12">
          <Lucideicons.credit_card class="h-12 w-12 mx-auto text-gray-400 mb-4" />
          <h3 class="text-lg font-medium text-gray-900 mb-2">
            <%= if @interval == "one_time" do %>
              No single purchase products found
            <% else %>
              No {@interval} plans found
            <% end %>
          </h3>
          <p class="text-gray-500 mb-4">
            <%= if @interval == "one_time" do %>
              Get started by creating your first single purchase product.
            <% else %>
              Get started by creating your first {@interval} subscription plan.
            <% end %>
          </p>
        </div>
      <% else %>
        <div class="flex flex-col gap-4">
          <%= for plan <- @interval_plans do %>
            <div class={[
              "border border-gray-200 rounded-lg p-6 cursor-pointer hover:bg-gray-50 transition-colors",
              if(@selected_item && @selected_type == :plan && @selected_item.id == plan.id,
                do: "bg-gray-100 border-l-4 border-blue-500",
                else: ""
              )
            ]}
            phx-click="select_plan"
            phx-value-id={plan.id}
            >
              <div class="flex justify-between items-center mb-4">
                <h4 class="text-lg font-semibold text-gray-900">{plan.name}</h4>
                <p class="text-sm text-gray-500 capitalize">{plan.metadata["tier"] || "Unknown"} Tier</p>
              </div>

              <div class="space-y-3">
                <div>
                  <p class="text-3xl font-bold text-gray-900">
                    {format_currency(plan.unit_amount)}
                  </p>
                  <p class="text-sm text-gray-500">
                    <%= if @interval == "one_time" do %>
                      one-time purchase
                    <% else %>
                      per {plan.interval}
                    <% end %>
                  </p>
                </div>

                <%= if plan.description do %>
                  <p class="text-sm text-gray-600">{plan.description}</p>
                <% end %>

                <div class="flex justify-between items-center border-t pt-3">
                  <p class="text-xs text-gray-400">Stripe ID: {plan.stripe_price_id}</p>
                  <p class="text-xs text-gray-400">{String.upcase(plan.currency)}</p>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Subscription Management
        <:subtitle>Manage subscription plans</:subtitle>
        <:actions>
          <div class="flex gap-2">

            <.button phx-click="new_plan">
              <Lucideicons.plus class="h-4 w-4 mr-2" />
              New <%= if @current_interval == "one_time", do: "Single Purchase", else: "#{String.capitalize(@current_interval)} Plan" %>
            </.button>
          </div>
        </:actions>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8 mt-4 h-[calc(100vh-200px)]">
        <div class="h-[calc(100vh-200px)] col-span-1">
          <TabsNew.tabs id="subscription-tabs" default={@active_tab} on_change="change_tab" :let={builder}>
            <TabsNew.tabs_list class="grid w-full grid-cols-3">
              <TabsNew.tabs_trigger builder={builder} value="monthly">Monthly</TabsNew.tabs_trigger>
              <TabsNew.tabs_trigger builder={builder} value="yearly">Yearly</TabsNew.tabs_trigger>
              <TabsNew.tabs_trigger builder={builder} value="one_time">Single Purchase</TabsNew.tabs_trigger>
            </TabsNew.tabs_list>

            <TabsNew.tabs_content value="monthly">
              <.plans_by_interval_tab
                plans={@plans}
                interval="monthly"
                loading={@loading}
                selected_item={@selected_item}
                selected_type={@selected_type}
              />
            </TabsNew.tabs_content>

            <TabsNew.tabs_content value="yearly">
              <.plans_by_interval_tab
                plans={@plans}
                interval="yearly"
                loading={@loading}
                selected_item={@selected_item}
                selected_type={@selected_type}
              />
            </TabsNew.tabs_content>

            <TabsNew.tabs_content value="one_time">
              <.plans_by_interval_tab
                plans={@plans}
                interval="one_time"
                loading={@loading}
                selected_item={@selected_item}
                selected_type={@selected_type}
              />
            </TabsNew.tabs_content>
          </TabsNew.tabs>
        </div>

        <div class="hidden lg:block col-span-1">
          <h2 class="text-xl font-semibold mb-4">Details</h2>
                    <%= if @selected_item do %>
            <.render_details
              selected_item={@selected_item}
              selected_type={@selected_type}
              editing_mode={@editing_mode}
              plan_form={@plan_form}
              features_order={@features_order}
              context="desktop"
            />
          <% else %>
            <p class="text-gray-500">Select an item to view details</p>
          <% end %>
        </div>
      </div>

      <div class="lg:hidden">
        <.drawer
          show={@show_drawer and @selected_item != nil}
          direction="bottom"
          on_cancel={JS.push("close_drawer")}
        >
          <.drawer_header>
            <.drawer_title>
              <%= case @selected_type do %>
                <% :plan -> %>Plan Details
                <% _ -> %>Details
              <% end %>
            </.drawer_title>
            <%= if @selected_item do %>
              <.drawer_description>
                <%= case @selected_type do %>
                  <% :plan -> %>{@selected_item.name}
                  <% _ -> %>
                <% end %>
              </.drawer_description>
            <% end %>
          </.drawer_header>
          <.drawer_content>
                        <%= if @selected_item do %>
              <.render_details
                selected_item={@selected_item}
                selected_type={@selected_type}
                editing_mode={@editing_mode}
                plan_form={@plan_form}
                features_order={@features_order}
                context="mobile"
              />
            <% end %>
          </.drawer_content>
        </.drawer>
      </div>

      <%!-- <.plan_modal
        show={@show_plan_modal}
        form={@plan_form}
        editing_plan={@editing_plan}
        loading={@loading}
      /> --%>
    </div>
    """
  end

    # Helper function to process plan parameters from the form
  defp process_plan_params(params) do
    # Handle features if they exist
    processed_params = if params["feature_keys"] && params["feature_values"] do
      feature_keys = params["feature_keys"] || []
      feature_values = params["feature_values"] || []

      # Combine keys and values into a features map, filtering out empty ones
      features =
        Enum.zip(feature_keys, feature_values)
        |> Enum.reject(fn {key, value} -> key == "" or value == "" end)
        |> Enum.into(%{})

      params
      |> Map.put("features", features)
      |> Map.delete("feature_keys")
      |> Map.delete("feature_values")
      |> Map.delete("features_to_remove")
    else
      params
    end

    # Convert unit_amount to integer if it's a string
    if processed_params["unit_amount"] && is_binary(processed_params["unit_amount"]) do
      case Integer.parse(processed_params["unit_amount"]) do
        {amount, ""} -> Map.put(processed_params, "unit_amount", amount)
        _ -> processed_params
      end
    else
      processed_params
    end
  end

      # Helper function to process plan parameters with feature ordering
  defp process_plan_params_with_order(params, features_order) do
    # Handle features from feature_keys and feature_values arrays (from form submission)
    processed_params = if params["feature_keys"] && params["feature_values"] do
      feature_keys = params["feature_keys"] || []
      feature_values = params["feature_values"] || []

      # If we have a features_order, use it to determine the correct order
      # Otherwise, use the order from the form arrays
      features = if length(features_order) > 0 do
        # Create a map from the form data first
        form_features =
          Enum.zip(feature_keys, feature_values)
          |> Enum.reject(fn {key, value} -> key == "" or value == "" end)
          |> Enum.into(%{})

        # Now reconstruct in the correct order using features_order
        features_order
        |> Enum.filter(&Map.has_key?(form_features, &1))  # Only include keys that still exist
        |> Enum.map(&{&1, form_features[&1]})
        |> Enum.into(%{})
      else
        # Fallback to form order if no features_order
        Enum.zip(feature_keys, feature_values)
        |> Enum.reject(fn {key, value} -> key == "" or value == "" end)
        |> Enum.into(%{})
      end

      params
      |> Map.put("features", features)
      |> Map.put("features_order", features_order)
      |> Map.delete("feature_keys")
      |> Map.delete("feature_values")
      |> Map.delete("features_to_remove")
    else
      # Fallback for when we have features directly and need to apply ordering
      if params["features"] && length(features_order) > 0 do
        current_features = params["features"]

        # Reconstruct features map in the specified order
        ordered_features =
          features_order
          |> Enum.filter(&Map.has_key?(current_features, &1))  # Only include keys that still exist
          |> Enum.map(&{&1, current_features[&1]})
          |> Enum.into(%{})

        params
        |> Map.put("features", ordered_features)
        |> Map.put("features_order", features_order)
      else
        params
      end
    end

    # Convert unit_amount to integer if it's a string
    if processed_params["unit_amount"] && is_binary(processed_params["unit_amount"]) do
      case Integer.parse(processed_params["unit_amount"]) do
        {amount, ""} -> Map.put(processed_params, "unit_amount", amount)
        _ -> processed_params
      end
    else
      processed_params
    end
  end

  # Helper function to find a plan in the structured plans data
  defp find_plan_in_structure(plan_id, plans) do
    plans
    |> Enum.flat_map(fn {_tier, tier_plans} ->
      [tier_plans.monthly, tier_plans.yearly]
      |> Enum.filter(& &1)
    end)
    |> Enum.find(&(&1.id == plan_id))
  end

  # Helper function to get ordered feature keys for display
  defp get_ordered_feature_keys(plan) do
    if plan.features_order && length(plan.features_order) > 0 do
      # Use the saved order from database
      plan.features_order
      |> Enum.filter(&Map.has_key?(plan.features || %{}, &1))  # Only include keys that exist in features
    else
      # Fallback to sorted keys if no order is defined
      Map.keys(plan.features || %{}) |> Enum.sort()
    end
  end

  # Helper function to format changeset errors
  defp format_changeset_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> Enum.map(fn {field, errors} ->
      "#{field}: #{Enum.join(errors, ", ")}"
    end)
    |> Enum.join("; ")
  end
end
