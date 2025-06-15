defmodule PhxplateWeb.Dashboard.SuperAdmin.AiResultsLive do
  @moduledoc """
  LiveView for viewing AI evaluation results.

  This view provides functionality for super admins to view and analyze
  the results of AI evaluations that have been run.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.AI
  alias PhxplateWeb.PageMeta
  import PhxplateWeb.Components.Markdown
  import PhxplateWeb.Components.AI.{PromptSelector, EvalSelector}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:show_drawer, false)
     |> assign(:selected_eval_run, nil)
     |> assign(:status_filter, "All Status")
     |> assign(:success_filter, "All Results")
     |> assign(:eval_filter, "All Evaluations")
     |> assign(:prompt_filter, "All Prompts")
     |> assign(:page, 1)
     |> assign(:per_page, 10)
     |> assign(:eval_runs, [])
     |> assign(:total_pages, 1)
     |> assign(:total_count, 0)
     |> assign(:screen_mode, "dialog")
     |> assign(:available_evals, load_available_evals())
     |> assign(:available_prompts, load_available_prompts())
     |> assign(:filter_reset_key, 0)
     |> load_eval_runs()
     |> PageMeta.assign_metadata(
       title: "AI Results",
       description: "View AI evaluation results",
       url: "/dashboard/super_admin/ai-results"
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
     |> load_eval_runs()}
  end

  @impl true
  def handle_event("view_results", %{"id" => id}, socket) do
    eval_run = AI.get_eval_run(id)

    # Debug logging for eval run query information
    IO.puts("=== DEBUG: View Results Clicked ===")
    IO.puts("Eval Run ID: #{id}")

    if eval_run do
      IO.puts("Eval Run Details:")
      IO.puts("  - Evaluation: #{eval_run.eval.name}")
      IO.puts("  - Model: #{eval_run.model}")
      IO.puts("  - Status: #{eval_run.status}")
      IO.puts("  - Score: #{inspect(eval_run.score)}")
      IO.puts("  - Prompt: #{if eval_run.prompt, do: eval_run.prompt.name, else: "Default System"}")
      IO.puts("  - Started At: #{inspect(eval_run.started_at)}")
      IO.puts("  - Completed At: #{inspect(eval_run.completed_at)}")
      IO.puts("  - Success Status: #{get_eval_run_success_status(eval_run)}")

      if eval_run.results && is_map(eval_run.results) do
        test_results = get_test_case_results(eval_run.results)
        IO.puts("  - Test Cases: #{length(test_results)}")

        for {test_name, result} <- test_results do
          IO.puts("    * #{test_name}: #{if Map.get(result, :passed), do: "PASSED", else: "FAILED"} (Score: #{format_score(Map.get(result, :score, "N/A"))})")
        end
      else
        IO.puts("  - No test results available")
      end
    else
      IO.puts("ERROR: Eval run not found!")
    end

    IO.puts("=== END DEBUG ===")

    {:noreply,
     socket
     |> assign(:show_drawer, true)
     |> assign(:selected_eval_run, eval_run)}
  end

  @impl true
  def handle_event("close_drawer", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_drawer, false)
     |> assign(:selected_eval_run, nil)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, status)
     |> assign(:page, 1)
     |> load_eval_runs()}
  end

  @impl true
  def handle_event("filter_success", %{"success" => success}, socket) do
    {:noreply,
     socket
     |> assign(:success_filter, success)
     |> assign(:page, 1)
     |> load_eval_runs()}
  end

  @impl true
  def handle_event("filter_eval", %{"eval" => eval_value}, socket) do
    {:noreply,
     socket
     |> assign(:eval_filter, eval_value)
     |> assign(:page, 1)
     |> load_eval_runs()}
  end

  @impl true
  def handle_event("filter_prompt", %{"prompt_name" => prompt_value}, socket) do
    {:noreply,
     socket
     |> assign(:prompt_filter, prompt_value)
     |> assign(:page, 1)
     |> load_eval_runs()}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)

    {:noreply,
     socket
     |> assign(:page, page)
     |> load_eval_runs()
     |> push_patch(to: ~p"/dashboard/super_admin/ai-results?page=#{page}")}
  end

  @impl true
  def handle_event("set_screen_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :screen_mode, mode)}
  end

  @impl true
  def handle_event("reset_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:status_filter, "All Status")
     |> assign(:success_filter, "All Results")
     |> assign(:eval_filter, "All Evaluations")
     |> assign(:prompt_filter, "All Prompts")
     |> assign(:page, 1)
     |> assign(:filter_reset_key, socket.assigns.filter_reset_key + 1)
     |> load_eval_runs()}
  end

  defp load_eval_runs(socket) do
    # Convert display text back to database values for status filter
    status_value = case socket.assigns.status_filter do
      "All Status" -> "all"
      other -> other
    end

    opts = [
      status: status_value
    ]

    # Filter by eval name
    opts =
      if socket.assigns.eval_filter not in ["All Evaluations", "No Eval Selected"] do
        case Enum.find(socket.assigns.available_evals, &(&1.name == socket.assigns.eval_filter)) do
          nil -> opts
          eval -> Keyword.put(opts, :eval_id, eval.id)
        end
      else
        opts
      end

    # Filter by prompt name
    opts =
      if socket.assigns.prompt_filter not in ["All Prompts"] do
        case socket.assigns.prompt_filter do
          "Default System" ->
            # Filter for evaluation runs with prompt_id: nil
            Keyword.put(opts, :prompt_id, nil)

          prompt_name ->
            case Enum.find(
                   socket.assigns.available_prompts,
                   &(&1.name == prompt_name)
                 ) do
              nil -> opts
              prompt -> Keyword.put(opts, :prompt_id, prompt.id)
            end
        end
      else
        opts
      end

    result = AI.list_all_eval_runs(socket.assigns.page, socket.assigns.per_page, opts)

    # Apply success filtering (client-side since it depends on results analysis)
    # Convert display text back to database values for success filter
    success_value = case socket.assigns.success_filter do
      "All Results" -> "all"
      other -> other
    end

    filtered_eval_runs = case success_value do
      "all" -> result.eval_runs
      success_filter ->
        Enum.filter(result.eval_runs, fn eval_run ->
          get_eval_run_success_status(eval_run) == success_filter
        end)
    end

    socket
    |> assign(:eval_runs, filtered_eval_runs)
    |> assign(:total_pages, result.total_pages)
    |> assign(:total_count, result.total_count)
  rescue
    # Handle case where tables don't exist yet
    _ ->
      socket
      |> assign(:eval_runs, [])
      |> assign(:total_pages, 1)
      |> assign(:total_count, 0)
  end

  defp load_available_evals do
    try do
      AI.list_evals()
    rescue
      _ -> []
    end
  end

  defp load_available_prompts do
    try do
      database_prompts = AI.list_prompts_for_chat()

      # Add the virtual "Default System" prompt that represents prompt_id: nil
      default_system_prompt = %{
        id: nil,
        name: "Default System",
        description: "Built-in default system prompt",
        category: "system"
      }

      [default_system_prompt | database_prompts]
    rescue
      _ -> [
        %{
          id: nil,
          name: "Default System",
          description: "Built-in default system prompt",
          category: "system"
        }
      ]
    end
  end

  defp format_score(score) when is_float(score) do
    :erlang.float_to_binary(score, decimals: 2)
  end

  defp format_score(score) when is_integer(score) do
    Integer.to_string(score)
  end

  defp format_score(_), do: "N/A"

  defp format_duration(started_at, completed_at)
       when not is_nil(started_at) and not is_nil(completed_at) do
    diff = DateTime.diff(completed_at, started_at, :second)

    cond do
      diff < 60 -> "#{diff}s"
      diff < 3600 -> "#{div(diff, 60)}m #{rem(diff, 60)}s"
      true -> "#{div(diff, 3600)}h #{div(rem(diff, 3600), 60)}m"
    end
  end

  defp format_duration(_, _), do: "N/A"

  defp status_badge_class(status) do
    case status do
      "completed" -> "bg-green-100 text-green-800"
      "failed" -> "bg-red-100 text-red-800"
      "running" -> "bg-blue-100 text-blue-800"
      "pending" -> "bg-yellow-100 text-yellow-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp get_test_case_results(results) when is_map(results) do
    results
    # Filter out error strings
    |> Enum.reject(fn {_key, value} -> is_binary(value) end)
    |> Enum.sort_by(fn {key, _value} -> key end)
  end

  defp get_test_case_results(_), do: []

  defp get_eval_run_success_status(eval_run) do
    case eval_run.status do
      "completed" ->
        if eval_run.results && is_map(eval_run.results) do
          test_results = get_test_case_results(eval_run.results)

          if Enum.empty?(test_results) do
            "unknown"
          else
            # Check if all test cases passed
            all_passed = Enum.all?(test_results, fn {_name, result} ->
              Map.get(result, :passed, false)
            end)

            if all_passed, do: "success", else: "partial"
          end
        else
          "unknown"
        end

      "failed" -> "failed"
      _ -> "unknown"
    end
  end

  defp success_status_badge_class(success_status) do
    case success_status do
      "success" -> "bg-green-100 text-green-800"
      "partial" -> "bg-yellow-100 text-yellow-800"
      "failed" -> "bg-red-100 text-red-800"
      _ -> "bg-gray-100 text-gray-800"
    end
  end

  defp success_status_text(success_status) do
    case success_status do
      "success" -> "All Passed"
      "partial" -> "Some Failed"
      "failed" -> "Failed"
      _ -> "Unknown"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        AI Results
        <:subtitle>View and analyze AI evaluation results</:subtitle>
      </.header>

      <div class="mt-4">
        <div class="mb-3 flex items-center justify-between md:justify-start">
          <span class="text-sm font-medium text-gray-700">Filters</span>
          <div class="md:hidden">
            <.button
              variant="outline"
              size="lg"
              phx-click="reset_filters"
              class="w-auto"
            >
              <Lucideicons.refresh_ccw class="w-4 h-4 -mx-4" />
            </.button>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3 md:flex md:flex-wrap md:gap-4 md:items-center" id={"filters-#{@filter_reset_key}"}>
          <form phx-change="filter_status" class="w-full md:w-auto">
            <.select :let={select} id="status-filter" name="status" value={@status_filter} key={"status-#{@filter_reset_key}"}>
              <.select_trigger builder={select} class="w-full md:w-48" />
              <.select_content builder={select} class="w-full md:w-48">
                <.select_item builder={select} value="All Status" label="All Status">
                  All Status
                </.select_item>
                <.select_item builder={select} value="completed" label="Completed">
                  Completed
                </.select_item>
                <.select_item builder={select} value="failed" label="Failed">
                  Failed
                </.select_item>
                <.select_item builder={select} value="running" label="Running">
                  Running
                </.select_item>
              </.select_content>
            </.select>
          </form>

          <form phx-change="filter_success" class="w-full md:w-auto">
            <.select :let={select} id="success-filter" name="success" value={@success_filter} key={"success-#{@filter_reset_key}"}>
              <.select_trigger builder={select} class="w-full md:w-48" />
              <.select_content builder={select} class="w-full md:w-48">
                <.select_item builder={select} value="All Results" label="All Results">
                  All Results
                </.select_item>
                <.select_item builder={select} value="success" label="All Passed">
                  All Passed
                </.select_item>
                <.select_item builder={select} value="partial" label="Some Failed">
                  Some Failed
                </.select_item>
                <.select_item builder={select} value="failed" label="Failed">
                  Failed
                </.select_item>
              </.select_content>
            </.select>
          </form>

          <%= if not Enum.empty?(@available_evals) do %>
            <div class="w-full md:w-auto">
              <.eval_selector
                available_evals={@available_evals}
                selected_eval={@eval_filter}
                on_change="filter_eval"
                class="w-full md:w-48"
                id="eval-filter"
                show_default={false}
                show_all_option={true}
                all_option_text="All Evaluations"
                all_option_value="All Evaluations"
                key={"eval-#{@filter_reset_key}"}
              />
            </div>
          <% end %>

          <%= if not Enum.empty?(@available_prompts) do %>
            <div class="w-full md:w-auto">
              <.prompt_selector
                available_prompts={@available_prompts}
                selected_prompt={@prompt_filter}
                on_change="filter_prompt"
                class="w-full md:w-48"
                id="prompt-filter"
                show_default={false}
                show_all_option={true}
                all_option_text="All Prompts"
                all_option_value="All Prompts"
                key={"prompt-#{@filter_reset_key}"}
              />
            </div>
          <% end %>

          <div class="hidden md:flex w-full md:w-auto justify-center md:justify-start">
            <.button
              variant="outline"
              size="lg"
              phx-click="reset_filters"
              class="w-full md:w-auto"
            >
              <Lucideicons.refresh_ccw class="w-4 h-4 -mx-4" />
            </.button>
          </div>
        </div>
      </div>

      <div class="mt-6">
        <%= if Enum.empty?(@eval_runs) do %>
          <.empty_state />
        <% else %>
          <.results_grid eval_runs={@eval_runs} />
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
        :if={@show_drawer && @selected_eval_run}
        id="ai-results-wrapper"
        show={@show_drawer}
        hook="DialogDrawerMode"
        mode={@screen_mode}
        on_cancel={JS.push("close_drawer")}
        name="Evaluation Results"
        description="Detailed results for this evaluation run"
        class="max-w-6xl max-h-[90vh] overflow-y-auto"
      >
        <.eval_run_details eval_run={@selected_eval_run} />
      </.dialog_drawer_wrapper>
    </div>
    """
  end

  defp empty_state(assigns) do
    ~H"""
    <div class="text-center py-12">
      <div class="mx-auto h-12 w-12 text-gray-400">
        <Lucideicons.chart_bar class="h-12 w-12" />
      </div>
      <h3 class="mt-2 text-sm font-medium text-gray-900">No evaluation results found</h3>
      <p class="mt-1 text-sm text-gray-500">
        Run some evaluations to see results here.
      </p>
    </div>
    """
  end

  defp results_grid(assigns) do
    ~H"""
    <div class="grid grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-6">
      <%= for eval_run <- @eval_runs do %>
        <div class="bg-white rounded-lg border border-gray-200 shadow-sm hover:shadow-md transition-shadow duration-200">
          <div class="p-6">
            <div class="flex items-start justify-between mb-4">
              <div class="flex-1 min-w-0">
                <h3 class="text-lg font-semibold text-gray-900 truncate">
                  {eval_run.eval.name}
                </h3>
                <%= if eval_run.prompt do %>
                  <p class="text-sm text-gray-500 mt-1">
                    Prompt: {String.slice(eval_run.prompt.name, 0, 25)}{if String.length(eval_run.prompt.name) > 25,do: "..."}
                  </p>
                <% end %>
              </div>
              <div class="flex flex-col gap-1 ml-2">
                <span class={[
                  "inline-flex px-2 py-1 text-xs font-semibold rounded-full whitespace-nowrap",
                  status_badge_class(eval_run.status)
                ]}>
                  {String.capitalize(eval_run.status)}
                </span>
                <% success_status = get_eval_run_success_status(eval_run) %>
                <%= if success_status != "unknown" do %>
                  <span class={[
                    "inline-flex px-2 py-1 text-xs font-semibold rounded-full whitespace-nowrap",
                    success_status_badge_class(success_status)
                  ]}>
                    {success_status_text(success_status)}
                  </span>
                <% end %>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4 mb-4">
              <div>
                <p class="text-sm font-medium text-gray-500">Model</p>
                <p class="text-sm text-gray-900 mt-1">{eval_run.model}</p>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-500">Score</p>
                <p class="text-sm text-gray-900 mt-1">
                  <%= if eval_run.score do %>
                    <span class="font-semibold">{format_score(eval_run.score)}</span>
                  <% else %>
                    N/A
                  <% end %>
                </p>
              </div>
            </div>

            <div class="grid grid-cols-2 gap-4 mb-4">
              <div>
                <p class="text-sm font-medium text-gray-500">Duration</p>
                <p class="text-sm text-gray-600 mt-1">
                  {format_duration(eval_run.started_at, eval_run.completed_at)}
                </p>
              </div>
              <div>
                <p class="text-sm font-medium text-gray-500">Run Date</p>
                <p class="text-sm text-gray-600 mt-1">
                  {Calendar.strftime(eval_run.inserted_at, "%m/%d %H:%M")}
                </p>
              </div>
            </div>

            <div class="flex justify-end">
              <.button
                variant="outline"
                size="sm"
                phx-click="view_results"
                phx-value-id={eval_run.id}
                disabled={eval_run.status not in ["completed", "failed"]}
                class="w-full"
              >
                <Lucideicons.eye class="h-4 w-4 mr-2" /> View Results
              </.button>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp eval_run_details(assigns) do
    ~H"""
    <%= if @eval_run do %>
      <div class="space-y-6">
        <div class="bg-gray-50 rounded-lg p-4">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <h3 class="text-lg font-medium text-gray-900">{@eval_run.eval.name}</h3>
              <p class="text-sm text-gray-600 mt-1">Model: {@eval_run.model}</p>
              <%= if @eval_run.prompt do %>
                <p class="text-sm text-gray-600">Prompt: {@eval_run.prompt.name}</p>
              <% end %>
            </div>
            <div class="text-right">
              <span class={[
                "inline-flex px-3 py-1 text-sm font-semibold rounded-full",
                status_badge_class(@eval_run.status)
              ]}>
                {String.capitalize(@eval_run.status)}
              </span>
              <%= if @eval_run.score do %>
                <p class="text-2xl font-bold text-gray-900 mt-2">
                  {format_score(@eval_run.score)}
                </p>
                <p class="text-sm text-gray-500">Overall Score</p>
              <% end %>
            </div>
          </div>
        </div>

        <%= if @eval_run.status == "completed" and @eval_run.results do %>
          <div>
            <h4 class="text-lg font-medium text-gray-900 mb-4">Test Case Results</h4>
            <div class="space-y-4">
              <%= for {test_name, result} <- get_test_case_results(@eval_run.results) do %>
                <div class="border border-gray-200 rounded-lg p-4">
                  <div class="flex items-center justify-between mb-3">
                    <h5 class="text-md font-medium text-gray-900">{test_name}</h5>
                    <div class="flex items-center gap-2">
                      <%= if Map.get(result, :score) do %>
                        <span class="text-sm font-medium text-gray-700">
                          Score: {format_score(Map.get(result, :score))}
                        </span>
                      <% end %>
                      <span class={[
                        "inline-flex px-2 py-1 text-xs font-semibold rounded-full",
                        if(Map.get(result, :passed),
                          do: "bg-green-100 text-green-800",
                          else: "bg-red-100 text-red-800"
                        )
                      ]}>
                        {if Map.get(result, :passed), do: "Passed", else: "Failed"}
                      </span>
                    </div>
                  </div>

                  <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
                    <div>
                      <h6 class="text-sm font-medium text-gray-700 mb-2">Input</h6>
                      <div class="bg-gray-50 rounded p-3 text-sm">
                        <pre class="whitespace-pre-wrap">{Map.get(result, :input, "")}</pre>
                      </div>
                    </div>

                    <div>
                      <h6 class="text-sm font-medium text-gray-700 mb-2">Expected Output</h6>
                      <div class="bg-gray-50 rounded p-3 text-sm">
                        <pre class="whitespace-pre-wrap">{Map.get(result, :expected, "")}</pre>
                      </div>
                    </div>

                    <div>
                      <h6 class="text-sm font-medium text-gray-700 mb-2">Actual Output</h6>
                      <div class="bg-gray-50 rounded p-3 text-sm max-h-40 overflow-y-auto">
                        <div class="prose prose-sm max-w-none">
                          {to_html(Map.get(result, :output, ""))}
                        </div>
                      </div>
                    </div>
                  </div>

                  <%= if Map.get(result, :reasoning) do %>
                    <div class="mt-4">
                      <h6 class="text-sm font-medium text-gray-700 mb-2">Judge Evaluation</h6>
                      <div class="bg-blue-50 rounded p-3 text-sm">
                        <pre class="whitespace-pre-wrap">{Map.get(result, :reasoning)}</pre>
                      </div>
                    </div>
                  <% end %>

                  <%= if Map.get(result, :error) do %>
                    <div class="mt-4">
                      <h6 class="text-sm font-medium text-red-700 mb-2">Error</h6>
                      <div class="bg-red-50 rounded p-3 text-sm text-red-800">
                        <pre class="whitespace-pre-wrap">{Map.get(result, :error)}</pre>
                      </div>
                    </div>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @eval_run.status == "failed" and @eval_run.results do %>
          <div>
            <h4 class="text-lg font-medium text-red-700 mb-4">Error Details</h4>
            <div class="bg-red-50 border border-red-200 rounded-lg p-4">
              <pre class="text-sm text-red-800 whitespace-pre-wrap">{inspect(@eval_run.results)}</pre>
            </div>
          </div>
        <% end %>

        <div class="flex justify-end pt-4 border-t border-gray-200">
          <.button variant="outline" phx-click="close_drawer" class="w-full">
            Close
          </.button>
        </div>
      </div>
    <% else %>
      <div class="space-y-4">
        <p class="text-sm text-gray-500">Loading evaluation results...</p>
        <div class="flex justify-end pt-4 border-t border-gray-200">
          <.button variant="outline" phx-click="close_drawer" class="w-full">
            Close
          </.button>
        </div>
      </div>
    <% end %>
    """
  end
end
