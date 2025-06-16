defmodule PhxplateWeb.Dashboard.SuperAdmin.SuperAdminLive do
  @moduledoc """
  LiveView for the super admin dashboard.

  This view provides an overview of application-wide statistics for super admins,
  including total user count, company count, employee count, subscription metrics,
  revenue data, and AI-related statistics. It subscribes to real-time updates for
  users, companies, employees, subscriptions, and feature requests via PubSub to
  ensure statistics stay current.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.{Accounts, Companies, Subscriptions, Chat, FeatureRequests, AI}
  alias PhxplateWeb.PageMeta
  alias Phxplate.PubSub.DataSync

  @doc """
  Initializes the LiveView with application statistics and PubSub subscriptions.

  Collects summary statistics about users, companies, employees, subscriptions,
  revenue, chat sessions, feature requests, feedback, AI conversations, prompts,
  evaluations, and evaluation results. Sets up PubSub subscriptions for real-time
  updates to these metrics.
  """
  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      # Subscribe to all relevant topics for real-time updates
      DataSync.subscribe("companies", "all")
      DataSync.subscribe("employees", "all")
      DataSync.subscribe("users", "all")
      DataSync.subscribe("subscriptions", "all")
      DataSync.subscribe("profiles", "all")
      DataSync.subscribe("feature_requests", "all")
    end

    stats = %{
      total_users: Accounts.count_users(),
      total_companies: Companies.count_companies(),
      total_employees: Companies.count_employees(),
      total_subscriptions: Subscriptions.count_active_subscriptions(),
      total_revenue: Subscriptions.calculate_total_revenue(),

      # Chat statistics
      total_chats: Chat.count_sessions(),
      open_chats: Chat.count_sessions(status: "active"),
      closed_chats: Chat.count_sessions(status: "closed"),

      # Feature requests and feedback
      total_feature_requests: FeatureRequests.count_feature_requests(request_type: :feature),
      total_feedback: FeatureRequests.count_feature_requests(request_type: :feedback),

      # AI statistics
      total_conversations: AI.count_conversations(),
      total_prompts: AI.count_prompts(),
      total_evaluations: AI.count_evals(),
      total_eval_runs: AI.count_eval_runs(),

      # Evaluation results by status
      pending_eval_runs: AI.count_eval_runs(status: "pending"),
      running_eval_runs: AI.count_eval_runs(status: "running"),
      completed_eval_runs: AI.count_eval_runs(status: "completed"),
      failed_eval_runs: AI.count_eval_runs(status: "failed")
    }

    {:ok,
     socket
     |> assign(:stats, stats)
     |> assign(:page_title, "Super Admin Dashboard")
     |> PageMeta.assign_metadata(
       title: "Super Admin Dashboard",
       description: "Super Admin Dashboard",
       url: "/dashboard/super_admin"
     )}
  end

  @impl true
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:noreply, socket}
  end

  # Handle employee creation - only global scope
  @impl true
  def handle_info({:created, %{type: :employee, employee: _employee, global_scope: true}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_employees: Companies.count_employees()}
     end)}
  end

  # Handle employee deletion with full employee data - only global scope
  def handle_info({:deleted, %{type: :employee, employee: _employee, global_scope: true}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_employees: Companies.count_employees()}
     end)}
  end

  # Handle company creation
  def handle_info({:created, %{type: :company, company: _company}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_companies: stats.total_companies + 1}
     end)}
  end

  # Handle company deletion
  def handle_info({:deleted, %{type: :company, id: _company_id}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_companies: stats.total_companies - 1}
     end)}
  end

  # Handle user creation
  def handle_info({:created, %{type: :user, user: _user}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_users: stats.total_users + 1}
     end)}
  end

  # Handle user deletion
  def handle_info({:deleted, %{type: :user, id: _user_id}}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{stats | total_users: stats.total_users - 1}
     end)}
  end

  # Handle subscription changes
  def handle_info({event, %{type: :subscription} = data}, socket) do
    case event do
      :created ->
        {:noreply,
         update(socket, :stats, fn stats ->
           %{
             stats
             | total_subscriptions: stats.total_subscriptions + 1,
               total_revenue: stats.total_revenue + (data.subscription.amount || 0)
           }
         end)}

      :deleted ->
        {:noreply,
         update(socket, :stats, fn stats ->
           %{
             stats
             | total_subscriptions: stats.total_subscriptions - 1,
               total_revenue: stats.total_revenue - (data.subscription.amount || 0)
           }
         end)}

      :updated ->
        # For updates, we only need to recalculate revenue if the amount changed
        if data.changes && Map.has_key?(data.changes, :amount) do
          old_amount = data.subscription.amount - data.changes.amount

          {:noreply,
           update(socket, :stats, fn stats ->
             %{stats | total_revenue: stats.total_revenue - old_amount + data.subscription.amount}
           end)}
        else
          {:noreply, socket}
        end
    end
  end

  # Handle feature request creation
  def handle_info({:created, _feature_request}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{
         stats
         | total_feature_requests: FeatureRequests.count_feature_requests(request_type: :feature),
           total_feedback: FeatureRequests.count_feature_requests(request_type: :feedback)
       }
     end)}
  end

  # Handle feature request deletion
  def handle_info({:deleted, _feature_request_id}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{
         stats
         | total_feature_requests: FeatureRequests.count_feature_requests(request_type: :feature),
           total_feedback: FeatureRequests.count_feature_requests(request_type: :feedback)
       }
     end)}
  end

  # Handle feature request updates
  def handle_info({:updated, _feature_request}, socket) do
    {:noreply,
     update(socket, :stats, fn stats ->
       %{
         stats
         | total_feature_requests: FeatureRequests.count_feature_requests(request_type: :feature),
           total_feedback: FeatureRequests.count_feature_requests(request_type: :feedback)
       }
     end)}
  end

  # Catch-all for any other events
  def handle_info(_message, socket), do: {:noreply, socket}

  defp dashboard_card(assigns) do
    ~H"""
    <div class={[
      "relative overflow-hidden rounded-lg p-4 shadow",
      if(Map.has_key?(@card, :link), do: "hover:bg-gray-50 transition-colors", else: "")
    ]}>
      <div class="absolute rounded-md p-3">
        <%= case @card.icon do %>
          <% "users" -> %>
            <Lucideicons.users class="h-8 w-8" />
          <% "building" -> %>
            <Lucideicons.building class="h-8 w-8" />
          <% "credit_card" -> %>
            <Lucideicons.credit_card class="h-8 w-8" />
          <% "dollar_sign" -> %>
            <Lucideicons.dollar_sign class="h-8 w-8" />
          <% "message_circle" -> %>
            <Lucideicons.message_circle class="h-8 w-8" />
          <% "message_circle_more" -> %>
            <Lucideicons.message_circle_more class="h-8 w-8" />
          <% "message_circle_x" -> %>
            <Lucideicons.message_circle_x class="h-8 w-8" />
          <% "lightbulb" -> %>
            <Lucideicons.lightbulb class="h-8 w-8" />
          <% "message_square_text" -> %>
            <Lucideicons.message_square_text class="h-8 w-8" />
          <% "bot" -> %>
            <Lucideicons.bot class="h-8 w-8" />
          <% "file_text" -> %>
            <Lucideicons.file_text class="h-8 w-8" />
          <% "clipboard_check" -> %>
            <Lucideicons.clipboard_check class="h-8 w-8" />
          <% "chart_bar" -> %>
            <Lucideicons.chart_bar class="h-8 w-8" />
          <% "clock" -> %>
            <Lucideicons.clock class="h-8 w-8" />
          <% "play" -> %>
            <Lucideicons.play class="h-8 w-8" />
          <% "circle_check" -> %>
            <Lucideicons.circle_check class="h-8 w-8" />
          <% "circle_x" -> %>
            <Lucideicons.circle_x class="h-8 w-8" />
        <% end %>
      </div>
      <div class="ml-16">
        <p class="truncate text-sm font-medium text-gray-500">{@card.title}</p>
        <p class="mt-1 text-3xl font-semibold text-gray-900">{@card.value}</p>
      </div>
    </div>
    """
  end

  defp get_dashboard_sections(stats) do
    [
      %{
        title: "User & Company Statistics",
        cards: [
          %{
            title: "Total Users",
            value: stats.total_users,
            icon: "users",
            link: ~p"/dashboard/super_admin/users"
          },
          %{
            title: "Total Companies",
            value: stats.total_companies,
            icon: "building",
            link: ~p"/dashboard/super_admin/companies"
          },
          %{
            title: "Total Employees",
            value: stats.total_employees,
            icon: "users",
          },
          %{
            title: "Active Subscriptions",
            value: stats.total_subscriptions,
            icon: "credit_card",
          },
          %{
            title: "Total Revenue",
            value: "$ #{stats.total_revenue}",
            icon: "dollar_sign",
          }
        ]
      },
      %{
        title: "Chat Statistics",
        cards: [
          %{
            title: "Total Chats",
            value: stats.total_chats,
            icon: "message_circle",
            link: ~p"/dashboard/super_admin/chat"
          },
          %{
            title: "Open Chats",
            value: stats.open_chats,
            icon: "message_circle_more",
          },
          %{
            title: "Closed Chats",
            value: stats.closed_chats,
            icon: "message_circle_x",
          }
        ]
      },
      %{
        title: "Feature Requests & Feedback",
        cards: [
          %{
            title: "Feature Requests",
            value: stats.total_feature_requests,
            icon: "lightbulb",
            link: ~p"/dashboard/super_admin/feature-feedbacks"
          },
          %{
            title: "Feedback",
            value: stats.total_feedback,
            icon: "message_square_text",
            link: ~p"/dashboard/super_admin/feature-feedbacks"
          }
        ]
      },
      %{
        title: "AI Statistics",
        cards: [
          %{
            title: "AI Conversations",
            value: stats.total_conversations,
            icon: "bot",
            link: ~p"/dashboard/super_admin/ai-chat"
          },
          %{
            title: "Total Prompts",
            value: stats.total_prompts,
            icon: "file_text",
            link: ~p"/dashboard/super_admin/ai-prompts"
          },
          %{
            title: "Total Evaluations",
            value: stats.total_evaluations,
            icon: "clipboard_check",
            link: ~p"/dashboard/super_admin/ai-evals"
          },
          %{
            title: "Total Eval Runs",
            value: stats.total_eval_runs,
            icon: "chart_bar",
            link: ~p"/dashboard/super_admin/ai-results"
          }
        ]
      },
      %{
        title: "Evaluation Results by Status",
        cards: [
          %{
            title: "Pending Evaluations",
            value: stats.pending_eval_runs,
            icon: "clock"
          },
          %{
            title: "Running Evaluations",
            value: stats.running_eval_runs,
            icon: "play"
          },
          %{
            title: "Completed Evaluations",
            value: stats.completed_eval_runs,
            icon: "circle_check"
          },
          %{
            title: "Failed Evaluations",
            value: stats.failed_eval_runs,
            icon: "circle_x"
          }
        ]
      }
    ]
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :dashboard_sections, get_dashboard_sections(assigns.stats))

        ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Super Admin Dashboard
        <:subtitle>View the stats of the application here</:subtitle>
      </.header>

      <div class="my-6 space-y-4 pb-6">
        <div :for={section <- @dashboard_sections}>
          <h3 class="text-lg font-medium text-gray-900 mb-4">{section.title}</h3>
          <div class="grid grid-cols-1 gap-6 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
            <div :for={card <- section.cards}>
              <%= if Map.has_key?(card, :link) do %>
                <.link navigate={card.link} class="block">
                  <.dashboard_card card={card} />
                </.link>
              <% else %>
                <.dashboard_card card={card} />
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
