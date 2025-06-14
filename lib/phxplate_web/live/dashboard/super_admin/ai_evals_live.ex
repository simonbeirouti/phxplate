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
  import PhxplateWeb.Components.UI.DialogDrawerWrapper
  import PhxplateWeb.Components.AI.ModelSelector
  import PhxplateWeb.Components.AI.PromptSelector

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
     |> assign(:page, 1)
     |> assign(:per_page, 10)
     |> assign(:evals, [])
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:screen_mode, "drawer")
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
     |> assign(:selected_item, changeset)}
  end

  @impl true
  def handle_event("edit_eval", %{"id" => id}, socket) do
    eval = AI.get_eval_with_creator(id)

    {:noreply,
     socket
     |> assign(:show_drawer, true)
     |> assign(:drawer_mode, "edit_eval")
     |> assign(:selected_item, eval)}
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
     |> assign(:selected_item, nil)}
  end

  @impl true
  def handle_event("save_eval", %{"eval" => eval_params}, socket) do
    current_user = socket.assigns.current_user
    eval_params = Map.put(eval_params, "created_by", current_user.id)

    # Parse test cases and expected outputs from form
    eval_params = parse_eval_form_data(eval_params)

    case socket.assigns.drawer_mode do
      "create_eval" ->
        case AI.create_eval(eval_params) do
          {:ok, _eval} ->
            {:noreply,
             socket
             |> put_flash(:info, "Evaluation created successfully")
             |> assign(:show_drawer, false)
             |> load_evals()}

          {:error, changeset} ->
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
  def handle_event("execute_eval", _params, socket) do
    eval = socket.assigns.selected_item
    current_user = socket.assigns.current_user
    model_api_id = Models.get_api_id(socket.assigns.selected_model)

    # Convert prompt name to ID for the AI.run_evaluation function
    prompt_id = case socket.assigns.selected_prompt_name do
      "Default System" -> nil
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
         |> put_flash(:info, "Evaluation started successfully with #{socket.assigns.selected_model}")
         |> assign(:show_drawer, false)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to start evaluation")}
    end
  end

  @impl true
  def handle_event("delete_eval", %{"id" => id}, socket) do
    eval = AI.get_eval(id)

    case AI.delete_eval(eval) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Evaluation deleted successfully")
         |> load_evals()}

      {:error, _} ->
        {:noreply,
         socket
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

  defp load_evals(socket) do
    result = AI.list_evals(socket.assigns.page, socket.assigns.per_page, [])

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

  defp parse_eval_form_data(params) do
    # Parse test cases from form format to map
    test_cases = parse_key_value_pairs(params["test_cases"] || "")
    expected_outputs = parse_key_value_pairs(params["expected_outputs"] || "")

    params
    |> Map.put("test_cases", test_cases)
    |> Map.put("expected_outputs", expected_outputs)
  end

  defp parse_key_value_pairs(text) when is_binary(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.with_index(1)
    |> Enum.map(fn {line, index} ->
      case String.split(line, ":", parts: 2) do
        [key, value] -> {String.trim(key), String.trim(value)}
        [value] -> {"test_#{index}", String.trim(value)}
      end
    end)
    |> Enum.into(%{})
  end

  defp format_key_value_pairs(map) when is_map(map) do
    map
    |> Enum.map(fn {key, value} -> "#{key}: #{value}" end)
    |> Enum.join("\n")
  end

  defp format_key_value_pairs(_), do: ""

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
            <.model_selector
              selected_model={@selected_model}
              on_change="select_model"
              class="w-[140px]"
            />
            <.button phx-click="create_eval" class="bg-black hover:bg-gray-800">
              <Lucideicons.plus class="h-4 w-4 mr-2" /> New Evaluation
            </.button>
          </div>
        </:actions>
      </.header>



      <!-- Content -->
      <div class="mt-6">
        <%= if Enum.empty?(@evals) do %>
          <.empty_state
            title="No evaluations found"
            description="Get started by creating your first AI evaluation."
            action_text="Create Evaluation"
            action_event="create_eval"
          />
        <% else %>
          <.evals_table evals={@evals} />
        <% end %>
      </div>

      <!-- Pagination -->
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

      <!-- Drawer -->
      <.dialog_drawer_wrapper
        :if={@show_drawer}
        id="ai-evals-wrapper"
        show={@show_drawer}
        hook="DialogDrawerMode"
        mode={@screen_mode}
        on_cancel={JS.push("close_drawer")}
        name={get_drawer_title(@drawer_mode)}
        description={get_drawer_description(@drawer_mode)}
      >
        <%= case @drawer_mode do %>
          <% mode when mode in ["create_eval", "edit_eval"] -> %>
            <.eval_form item={@selected_item} mode={@drawer_mode} />
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

  defp evals_table(assigns) do
    ~H"""
    <div class="overflow-hidden shadow ring-1 ring-black ring-opacity-5 md:rounded-lg">
      <table class="min-w-full divide-y divide-gray-300">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Test Cases</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created By</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Created</th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Status</th>
            <th class="relative px-6 py-3"><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for eval <- @evals do %>
            <tr>
              <td class="px-6 py-4 whitespace-nowrap">
                <div class="text-sm font-medium text-gray-900">{eval.name}</div>
                <%= if eval.description do %>
                  <div class="text-sm text-gray-500">{String.slice(eval.description, 0, 60)}...</div>
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {map_size(eval.test_cases)} test cases
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                {if eval.created_by_user, do: eval.created_by_user.email, else: "System"}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {Calendar.strftime(eval.inserted_at, "%b %d, %Y")}
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <span class={[
                  "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                  if(eval.is_active, do: "bg-green-100 text-green-800", else: "bg-red-100 text-red-800")
                ]}>
                  {if eval.is_active, do: "Active", else: "Inactive"}
                </span>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                <.button variant="ghost" size="sm" phx-click="run_eval" phx-value-id={eval.id}>
                  <Lucideicons.play class="h-4 w-4" />
                </.button>
                <.button variant="ghost" size="sm" phx-click="edit_eval" phx-value-id={eval.id}>
                  <Lucideicons.pencil class="h-4 w-4" />
                </.button>
                <.button variant="ghost" size="sm" phx-click="delete_eval" phx-value-id={eval.id} data-confirm="Are you sure?">
                  <Lucideicons.trash_2 class="h-4 w-4" />
                </.button>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp eval_form(assigns) do
    changeset = case assigns.item do
      %Ecto.Changeset{} -> assigns.item
      item -> Eval.changeset(item, %{})
    end

    assigns = assign(assigns, :changeset, changeset)

    ~H"""
    <.form :let={f} for={@changeset} phx-submit="save_eval">
      <div class="space-y-4">
        <.input field={f[:name]} label="Name" required />

        <div>
          <.label>Test Cases</.label>
          <.input
            type="textarea"
            name="eval[test_cases]"
            value={format_key_value_pairs(Ecto.Changeset.get_field(@changeset, :test_cases, %{}))}
            rows="6"
            required
          />
          <p class="mt-1 text-sm text-gray-500">
            Enter test cases as "name: question" pairs, one per line
          </p>
        </div>

        <div>
          <.label>Expected Outputs</.label>
          <.input
            type="textarea"
            name="eval[expected_outputs]"
            value={format_key_value_pairs(Ecto.Changeset.get_field(@changeset, :expected_outputs, %{}))}
            rows="6"
          />
          <p class="mt-1 text-sm text-gray-500">
            Enter expected outputs as "name: expected_answer" pairs, one per line
          </p>
        </div>

        <.input field={f[:evaluation_criteria]} type="textarea" label="Evaluation Criteria" rows="4" required />

        <div class="flex items-center">
          <.input field={f[:is_active]} type="checkbox" label="Active" />
        </div>
      </div>

      <div class="mt-6 flex flex-col space-y-3">
        <.button type="submit" class="w-full">
          <%= if @mode == "create_eval", do: "Create Evaluation", else: "Update Evaluation" %>
        </.button>
        <.button type="button" variant="outline" phx-click="close_drawer" class="w-full">Cancel</.button>
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
          <%= if @item.description do %>
            <p class="text-sm text-gray-500">{@item.description}</p>
          <% end %>
          <p class="text-sm text-gray-600 mt-2">
            <strong>Test Cases:</strong> {map_size(@item.test_cases)}
          </p>
        </div>

        <div class="bg-gray-50 p-4 rounded-lg">
          <p class="text-sm text-gray-700">
            <strong>Selected Model:</strong> {@selected_model}
          </p>
          <p class="text-xs text-gray-500 mt-1">
            Change the model using the selector in the header if needed.
          </p>
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
          <.button type="button" variant="outline" phx-click="close_drawer" class="w-full">Cancel</.button>
        </div>
      </div>
    <% else %>
      <div class="space-y-4">
        <p class="text-sm text-gray-500">Loading evaluation...</p>
        <div class="mt-6 flex flex-col space-y-3">
          <.button type="button" variant="outline" phx-click="close_drawer" class="w-full">Cancel</.button>
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
