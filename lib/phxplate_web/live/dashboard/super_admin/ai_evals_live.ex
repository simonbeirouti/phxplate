defmodule PhxplateWeb.Dashboard.SuperAdmin.AiEvalsLive do
  @moduledoc """
  LiveView for managing AI evaluations.

  This view provides functionality for super admins to create, edit, and manage
  AI evaluations, as well as run evaluations against different models.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.AI
  alias Phxplate.AI.{Eval, Models}
  alias PhxplateWeb.PageMeta
  import PhxplateWeb.Components.AI.PromptSelector
  import PhxplateWeb.Components.UI.Select

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_drawer, false)
     |> assign(:drawer_mode, "create")
     |> assign(:selected_item, nil)
     |> assign(:available_models, Models.available_models())
     |> assign(:selected_model, Models.default_model_display_name())
     |> assign(:selected_prompt_name, "Default System")
     |> assign(:prompts, load_prompts())
     |> assign(:test_cases, [])
     |> assign(:status_filter, "All Status")
     |> assign(:page, 1)
     |> assign(:per_page, 10)
     |> assign(:evals, [])
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:screen_mode, "dialog")
     |> assign(:delete_eval_id, nil)
     |> load_evals()
     |> PageMeta.assign_metadata(
       title: "AI Evaluations",
       description: "Manage AI evaluations",
       url: "/dashboard/super_admin/ai-evals"
     )}
  end

  @impl true
  def handle_params(params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    page = String.to_integer(Map.get(params, "page", "1"))

    {:noreply,
     socket
     |> assign(:page, page)
     |> load_evals()}
  end

  @impl true
  def handle_event("select_model", %{"model" => model}, socket) do
    {:noreply, assign(socket, :selected_model, model)}
  end

  @impl true
  def handle_event("create_eval", _params, socket) do
    # Create a changeset with default values for a new evaluation
    changeset = Eval.changeset(%Eval{}, %{"is_active" => true})

    {:noreply,
     socket
     |> assign(:show_drawer, true)
     |> assign(:drawer_mode, "create_eval")
     |> assign(:selected_item, changeset)
     |> assign(:test_cases, [%{id: generate_temp_id(), test_case: "", expected_output: ""}])}
  end

  @impl true
  def handle_event("edit_eval", %{"id" => id}, socket) do
    eval = AI.get_eval_with_creator(id)

    # Convert existing test cases and expected outputs to the new format
    test_cases = convert_maps_to_test_cases(eval.test_cases, eval.expected_outputs)

    {:noreply,
     socket
     |> assign(:show_drawer, true)
     |> assign(:drawer_mode, "edit_eval")
     |> assign(:selected_item, eval)
     |> assign(:test_cases, test_cases)}
  end

  @impl true
  def handle_event("run_eval", %{"id" => id}, socket) do
    eval = AI.get_eval_with_creator(id)

    {:noreply,
     socket
     |> assign(:show_drawer, true)
     |> assign(:drawer_mode, "run_eval")
     |> assign(:selected_item, eval)}
  end

  @impl true
  def handle_event("close_drawer", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_drawer, false)
     |> assign(:selected_item, nil)
     |> assign(:test_cases, [])}
  end

  @impl true
  def handle_event("save_eval", %{"eval" => eval_params}, socket) do
    current_user = socket.assigns.current_user
    eval_params = Map.put(eval_params, "created_by", current_user.id)

    # Convert test cases to the expected format
    eval_params = convert_test_cases_to_maps(eval_params, socket.assigns.test_cases)

    case socket.assigns.drawer_mode do
      "create_eval" ->
        case AI.create_eval(eval_params) do
          {:ok, _eval} ->
            {:noreply,
             socket
             |> put_flash(:info, "Evaluation created successfully")
             |> assign(:show_drawer, false)
             |> load_evals()}

          {:error, _changeset} ->
            {:noreply,
             socket
             |> assign(:selected_item, %Eval{} |> Eval.changeset(eval_params))
             |> put_flash(:error, "Failed to create evaluation")}
        end

      "edit_eval" ->
        case AI.update_eval(socket.assigns.selected_item, eval_params) do
          {:ok, _eval} ->
            {:noreply,
             socket
             |> put_flash(:info, "Evaluation updated successfully")
             |> assign(:show_drawer, false)
             |> load_evals()}

          {:error, changeset} ->
            {:noreply,
             socket
             |> assign(:selected_item, changeset)
             |> put_flash(:error, "Failed to update evaluation")}
        end
    end
  end

  @impl true
  def handle_event("prompt_changed", %{"prompt_name" => prompt_name}, socket) do
    {:noreply, assign(socket, :selected_prompt_name, prompt_name)}
  end

  @impl true
  def handle_event("status_changed", %{"value" => value}, socket) do
    # Convert string to boolean
    is_active =
      case value do
        "true" -> true
        "false" -> false
        _ -> true
      end

    # Update the changeset with the selected status
    current_data =
      case socket.assigns.selected_item do
        %Ecto.Changeset{data: data, changes: changes} ->
          Map.merge(data, changes)

        item ->
          item
      end

    changeset = Eval.changeset(current_data, %{"is_active" => is_active})

    {:noreply, assign(socket, :selected_item, changeset)}
  end

  @impl true
  def handle_event("execute_eval", _params, socket) do
    eval = socket.assigns.selected_item
    current_user = socket.assigns.current_user
    model_api_id = Models.get_api_id(socket.assigns.selected_model)

    # Convert prompt name to ID for the AI.run_evaluation function
    prompt_id =
      case socket.assigns.selected_prompt_name do
        "Default System" ->
          nil

        prompt_name ->
          case Enum.find(socket.assigns.prompts, &(&1.name == prompt_name)) do
            nil -> nil
            prompt -> prompt.id
          end
      end

    case AI.run_evaluation(eval.id, model_api_id, current_user.id, prompt_id) do
      {:ok, _eval_run} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Evaluation started successfully with #{socket.assigns.selected_model}"
         )
         |> assign(:show_drawer, false)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start evaluation")}
    end
  end

  @impl true
  def handle_event("prepare_delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :delete_eval_id, String.to_integer(id))}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :delete_eval_id, nil)}
  end

  @impl true
  def handle_event("confirm_delete", %{"id" => id}, socket) do
    eval = AI.get_eval(id)

    case AI.delete_eval(eval) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:delete_eval_id, nil)
         |> put_flash(:info, "Evaluation deleted successfully")
         |> load_evals()}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:delete_eval_id, nil)
         |> put_flash(:error, "Failed to delete evaluation")}
    end
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> load_evals()
     |> push_patch(to: ~p"/dashboard/super_admin/ai-evals?page=#{page}")}
  end

  @impl true
  def handle_event("set_screen_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :screen_mode, mode)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:page, 1)
     |> load_evals()}
  end

  @impl true
  def handle_event("toggle_status", %{"status_toggle" => status}, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:page, 1)
     |> load_evals()}
  end

  @impl true
  def handle_event("add_test_case", _params, socket) do
    new_test_case = %{id: generate_temp_id(), test_case: "", expected_output: ""}
    updated_test_cases = socket.assigns.test_cases ++ [new_test_case]

    {:noreply, assign(socket, :test_cases, updated_test_cases)}
  end

  @impl true
  def handle_event("remove_test_case", %{"id" => id}, socket) do
    updated_test_cases = Enum.reject(socket.assigns.test_cases, &(&1.id == id))

    {:noreply, assign(socket, :test_cases, updated_test_cases)}
  end

  @impl true
  def handle_event("update_test_case", %{"id" => id, "field" => field, "value" => value}, socket) do
    updated_test_cases =
      Enum.map(socket.assigns.test_cases, fn test_case ->
        if test_case.id == id do
          Map.put(test_case, String.to_atom(field), value)
        else
          test_case
        end
      end)

    {:noreply, assign(socket, :test_cases, updated_test_cases)}
  end

  defp load_evals(socket) do
    # Convert display text back to database values for status filter
    status_value = case socket.assigns.status_filter do
      "All Status" -> "all"
      "Active" -> "active"
      "Inactive" -> "inactive"
      other -> other
    end

    opts = [
      status: status_value
    ]

    result = AI.list_evals(socket.assigns.page, socket.assigns.per_page, opts)

    socket
    |> assign(:evals, result.evals)
    |> assign(:total_pages, result.total_pages)
    |> assign(:total_count, result.total_count)
  rescue
    # Handle case where tables don't exist yet
    _ ->
      socket
      |> assign(:evals, [])
      |> assign(:total_pages, 1)
      |> assign(:total_count, 0)
  end

  defp generate_temp_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp convert_test_cases_to_maps(params, test_cases) do
    # Filter out empty test cases
    valid_test_cases =
      Enum.reject(test_cases, fn tc ->
        String.trim(tc.test_case) == "" || String.trim(tc.expected_output) == ""
      end)

    test_cases_map =
      valid_test_cases
      |> Enum.with_index(1)
      |> Enum.map(fn {tc, index} -> {"test_#{index}", tc.test_case} end)
      |> Enum.into(%{})

    expected_outputs_map =
      valid_test_cases
      |> Enum.with_index(1)
      |> Enum.map(fn {tc, index} -> {"test_#{index}", tc.expected_output} end)
      |> Enum.into(%{})

    params
    |> Map.put("test_cases", test_cases_map)
    |> Map.put("expected_outputs", expected_outputs_map)
  end

  defp convert_maps_to_test_cases(test_cases_map, expected_outputs_map)
       when is_map(test_cases_map) and is_map(expected_outputs_map) do
    # Get all keys from both maps
    all_keys =
      MapSet.union(
        MapSet.new(Map.keys(test_cases_map)),
        MapSet.new(Map.keys(expected_outputs_map))
      )

    all_keys
    |> Enum.sort()
    |> Enum.map(fn key ->
      %{
        id: generate_temp_id(),
        test_case: Map.get(test_cases_map, key, ""),
        expected_output: Map.get(expected_outputs_map, key, "")
      }
    end)
    |> case do
      [] -> [%{id: generate_temp_id(), test_case: "", expected_output: ""}]
      test_cases -> test_cases
    end
  end

  defp convert_maps_to_test_cases(_, _) do
    [%{id: generate_temp_id(), test_case: "", expected_output: ""}]
  end

  defp load_prompts do
    try do
      AI.list_prompts()
    rescue
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        AI Evaluations
        <:subtitle>Manage AI evaluations and test suites</:subtitle>
        <:actions>
          <div class="flex items-center gap-3">
            <form phx-change="filter_status" class="w-auto">
              <.select :let={select} id="status-filter" name="status" value={@status_filter}>
                <.select_trigger builder={select} class="w-32" />
                <.select_content builder={select} class="w-32">
                  <.select_item builder={select} value="All Status" label="All Status">
                    All Status
                  </.select_item>
                  <.select_item builder={select} value="Active" label="Active">
                    Active
                  </.select_item>
                  <.select_item builder={select} value="Inactive" label="Inactive">
                    Inactive
                  </.select_item>
                </.select_content>
              </.select>
            </form>
            <.button phx-click="create_eval" class="bg-black hover:bg-gray-800">
              <Lucideicons.plus class="h-4 w-4 mr-2 hidden sm:inline" />
              <span class="hidden sm:inline">New Evaluation</span>
              <Lucideicons.plus class="h-4 w-4 sm:hidden" />
            </.button>
          </div>
        </:actions>
      </.header>

      <div class="mt-6">
        <%= if Enum.empty?(@evals) do %>
          <.empty_state
            title="No evaluations found"
            description="Get started by creating your first AI evaluation."
            action_text="Create Evaluation"
            action_event="create_eval"
          />
        <% else %>
          <.evals_grid evals={@evals} delete_eval_id={@delete_eval_id} />
        <% end %>
      </div>

      <%= if @total_pages > 1 do %>
        <div class="mt-6">
          <.pagination>
            <.pagination_content class="w-full flex justify-center items-center">
              <%= if @page > 1 do %>
                <.pagination_item>
                  <.pagination_link phx-click="paginate" phx-value-page={@page - 1}>
                    <Lucideicons.arrow_left class="w-3.5 h-3.5" />
                  </.pagination_link>
                </.pagination_item>
              <% end %>

              <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                <.pagination_item>
                  <.pagination_link
                    phx-click="paginate"
                    phx-value-page={page_num}
                    is-active={page_num == @page}
                  >
                    {page_num}
                  </.pagination_link>
                </.pagination_item>
              <% end %>

              <%= if @page < @total_pages do %>
                <.pagination_item>
                  <.pagination_link phx-click="paginate" phx-value-page={@page + 1}>
                    <Lucideicons.arrow_right class="w-3.5 h-3.5" />
                  </.pagination_link>
                </.pagination_item>
              <% end %>
            </.pagination_content>
          </.pagination>
        </div>
      <% end %>

      <.dialog_drawer_wrapper
        :if={@show_drawer}
        id="ai-evals-wrapper"
        show={@show_drawer}
        hook="DialogDrawerMode"
        mode={@screen_mode}
        on_cancel={JS.push("close_drawer")}
        name={get_drawer_title(@drawer_mode)}
        description={get_drawer_description(@drawer_mode)}
        class="max-w-6xl max-h-[90vh] overflow-y-auto"
      >
        <%= case @drawer_mode do %>
          <% mode when mode in ["create_eval", "edit_eval"] -> %>
            <.eval_form item={@selected_item} mode={@drawer_mode} test_cases={@test_cases} />
          <% "run_eval" -> %>
            <.eval_run_form
              item={@selected_item}
              selected_model={@selected_model}
              prompts={@prompts}
              selected_prompt_name={@selected_prompt_name}
            />
        <% end %>
      </.dialog_drawer_wrapper>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="mx-auto h-12 w-12 text-gray-400">
        <Lucideicons.clipboard_check class="h-12 w-12" />
      </div>
      <h3 class="mt-2 text-sm font-medium text-gray-900">{@title}</h3>
      <p class="mt-1 text-sm text-gray-500">{@description}</p>
      <div class="mt-6">
        <.button phx-click={@action_event} class="bg-black hover:bg-gray-800">
          <Lucideicons.plus class="h-4 w-4 mr-2" />
          {@action_text}
        </.button>
      </div>
    </div>
    """
  end

  defp evals_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <%= for eval <- @evals do %>
        <div class="bg-white rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow duration-200">
          <div class="p-6">
            <div class="flex items-start justify-between mb-4">
              <h3 class="text-lg font-semibold text-gray-900 truncate pr-2">
                {eval.name}
              </h3>
              <span class={[
                "inline-flex px-2 py-1 text-xs font-semibold rounded-full whitespace-nowrap",
                if(eval.is_active,
                  do: "bg-green-100 text-green-800",
                  else: "bg-red-100 text-red-800"
                )
              ]}>
                {if eval.is_active, do: "Active", else: "Inactive"}
              </span>
            </div>

            <div class="mb-4 space-y-2">
              <p class="text-sm text-gray-600">
                <strong>Test Cases:</strong> {map_size(eval.test_cases)}
              </p>
              <%= if eval.evaluation_criteria && String.trim(eval.evaluation_criteria) != "" do %>
                <p class="text-xs text-gray-600 leading-relaxed">
                  {String.slice(eval.evaluation_criteria, 0, 250)}{if String.length(eval.evaluation_criteria) > 250, do: "..."}
                </p>
              <% end %>
            </div>

            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-2">
                <.button variant="outline" size="sm" phx-click="run_eval" phx-value-id={eval.id}>
                  <Lucideicons.play class="h-4 w-4" />
                </.button>
                <.button variant="outline" size="sm" phx-click="edit_eval" phx-value-id={eval.id}>
                  <Lucideicons.pencil class="h-4 w-4" />
                </.button>
              </div>

              <div class="flex items-center space-x-1">
                <%= if @delete_eval_id && @delete_eval_id == eval.id do %>
                  <.button
                    variant="destructive"
                    size="sm"
                    phx-click="confirm_delete"
                    phx-value-id={eval.id}
                    title="Click to confirm deletion"
                  >
                    <Lucideicons.check class="h-4 w-4" />
                  </.button>
                  <.button
                    variant="outline"
                    size="sm"
                    phx-click="cancel_delete"
                    title="Cancel deletion"
                  >
                    <Lucideicons.x class="h-4 w-4" />
                  </.button>
                <% else %>
                  <.button
                    variant="outline"
                    size="sm"
                    phx-click="prepare_delete"
                    phx-value-id={eval.id}
                    title="Delete evaluation"
                  >
                    <Lucideicons.trash_2 class="h-4 w-4" />
                  </.button>
                <% end %>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp eval_form(assigns) do
    changeset =
      case assigns.item do
        %Ecto.Changeset{} -> assigns.item
        item -> Eval.changeset(item, %{})
      end

    assigns = assign(assigns, :changeset, changeset)

    ~H"""
    <.form :let={f} for={@changeset} phx-submit="save_eval">
      <div class="space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <.input field={f[:name]} label="Name" required />
          </div>
          <div>
            <.label>Status</.label>
            <div class="mt-2 w-full">
              <% current_status =
                case @changeset do
                  %Ecto.Changeset{} ->
                    Ecto.Changeset.get_field(@changeset, :is_active)

                  _ ->
                    true
                end %>
              <.toggle_group
                :let={builder}
                name="eval[is_active]"
                size="sm"
                variant="outline"
                value={if current_status, do: "true", else: "false"}
                phx-change="status_changed"
                class="w-full flex justify-between"
              >
                <.toggle_group_item value="true" builder={builder} aria-label="Active" class="flex-1">
                  Active
                </.toggle_group_item>
                <.toggle_group_item
                  value="false"
                  builder={builder}
                  aria-label="Inactive"
                  class="flex-1"
                >
                  Inactive
                </.toggle_group_item>
              </.toggle_group>
            </div>
          </div>
        </div>

        <div>
          <div class="flex items-center justify-between mb-3">
            <.label>Test Cases</.label>
            <.button type="button" variant="outline" size="sm" phx-click="add_test_case">
              <Lucideicons.plus class="h-4 w-4 mr-1" /> Add Test Case
            </.button>
          </div>

          <div class="space-y-4">
            <%= for {test_case, index} <- Enum.with_index(@test_cases) do %>
              <div class="border border-gray-200 rounded-lg p-4 bg-gray-50">
                <div class="flex items-center justify-between mb-3">
                  <h4 class="text-sm font-medium text-gray-900">Test Case #{index + 1}</h4>
                  <%= if length(@test_cases) > 1 do %>
                    <.button
                      type="button"
                      variant="ghost"
                      size="sm"
                      phx-click="remove_test_case"
                      phx-value-id={test_case.id}
                    >
                      <Lucideicons.trash_2 class="h-4 w-4" />
                    </.button>
                  <% end %>
                </div>

                <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <.label>Test Input</.label>
                    <.input
                      name={"test_case_#{test_case.id}"}
                      value={test_case.test_case}
                      phx-blur="update_test_case"
                      phx-value-id={test_case.id}
                      phx-value-field="test_case"
                      rows="3"
                      placeholder="Enter the test input/question..."
                    />
                  </div>
                  <div>
                    <.label>Expected Output</.label>
                    <.input
                      name={"expected_output_#{test_case.id}"}
                      value={test_case.expected_output}
                      phx-blur="update_test_case"
                      phx-value-id={test_case.id}
                      phx-value-field="expected_output"
                      rows="3"
                      placeholder="Enter the expected response..."
                    />
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div>
          <.input
            field={f[:evaluation_criteria]}
            type="textarea"
            label="Evaluation Criteria"
            rows="4"
            required
          />
        </div>
      </div>

      <div class="mt-6 flex flex-col space-y-3">
        <.button type="submit" class="w-full">
          {if @mode == "create_eval", do: "Create Evaluation", else: "Update Evaluation"}
        </.button>
        <.button type="button" variant="outline" phx-click="close_drawer" class="w-full">
          Cancel
        </.button>
      </div>
    </.form>
    """
  end

  defp eval_run_form(assigns) do
    ~H"""
    <%= if @item do %>
      <div class="space-y-4">
        <div>
          <h3 class="text-lg font-medium">{@item.name}</h3>
          <p class="text-sm text-gray-500">{@item.evaluation_criteria}</p>
        </div>

        <div>
          <h4 class="text-sm font-medium text-gray-900 mb-3">Test Cases ({map_size(@item.test_cases)})</h4>
          <div class="space-y-3">
            <%= for {key, test_case} <- @item.test_cases do %>
              <% expected_output = Map.get(@item.expected_outputs, key, "") %>
              <div class="border border-gray-200 rounded-lg p-3 bg-gray-50">
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
                  <div>
                    <.label class="text-xs font-medium text-gray-700">Test Input</.label>
                    <div class="mt-1 p-2 bg-white border border-gray-200 rounded text-sm">
                      {test_case}
                    </div>
                  </div>
                  <div>
                    <.label class="text-xs font-medium text-gray-700">Expected Output</.label>
                    <div class="mt-1 p-2 bg-white border border-gray-200 rounded text-sm">
                      {expected_output}
                    </div>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </div>

        <div>
          <.label>Prompt (Optional)</.label>
          <.prompt_selector
            available_prompts={@prompts}
            selected_prompt={@selected_prompt_name}
            on_change="prompt_changed"
            id="eval-prompt-selector"
          />
        </div>

        <div class="mt-6 flex flex-col space-y-3">
          <.button phx-click="execute_eval" class="w-full">Run Evaluation</.button>
          <.button type="button" variant="outline" phx-click="close_drawer" class="w-full">
            Cancel
          </.button>
        </div>
      </div>
    <% else %>
      <div class="space-y-4">
        <p class="text-sm text-gray-500">Loading evaluation...</p>
        <div class="mt-6 flex flex-col space-y-3">
          <.button type="button" variant="outline" phx-click="close_drawer" class="w-full">
            Cancel
          </.button>
        </div>
      </div>
    <% end %>
    """
  end

  defp get_drawer_title("create_eval"), do: "Create New Evaluation"
  defp get_drawer_title("edit_eval"), do: "Edit Evaluation"
  defp get_drawer_title("run_eval"), do: "Run Evaluation"

  defp get_drawer_description("create_eval"), do: "Create a new AI evaluation for your collection"
  defp get_drawer_description("edit_eval"), do: "Edit the selected AI evaluation"
  defp get_drawer_description("run_eval"), do: "Run evaluation against selected model"
end
