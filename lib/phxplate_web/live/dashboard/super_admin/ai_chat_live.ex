defmodule PhxplateWeb.Dashboard.SuperAdmin.AiChatLive do
  @moduledoc """
  LiveView for testing the AI Chat functionality with persistence.

  This view allows super admins to test the Anthropic Claude integration
  with a chat interface that persists conversations and messages.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.AI
  alias Phxplate.AI.Models
  alias PhxplateWeb.PageMeta
  alias PhxplateWeb.Components.Markdown
  import PhxplateWeb.Components.AI.{ModelSelector, PromptSelector, EvalSelector}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    conversations = AI.list_conversations(user_id)
    all_prompts = AI.list_prompts_for_chat()
    all_evals = AI.list_evals()
    default_system_prompt = AI.get_default_system_prompt()

    {:ok,
     socket
     |> assign(:conversations, conversations)
     |> assign(:current_conversation, nil)
     |> assign(:messages, [])
     |> assign(:input_message, "")
     |> assign(:loading, false)
     |> assign(:streaming, false)
     |> assign(:current_stream, "")
     |> assign(:sidebar_open, true)
     |> assign(:show_mobile_drawer, false)
     |> assign(:editing_title, nil)
     |> assign(:new_title, "")
     |> assign(:deleting_conversation, nil)
     |> assign(:selected_model, Models.default_model_display_name())
     |> assign(:available_models, Models.available_models())
     |> assign(:available_prompts, all_prompts)
     |> assign(:available_evals, all_evals)
     |> assign(:selected_eval, get_default_eval_selection(all_evals))
     |> assign(:selected_system_prompt, get_default_system_prompt_name(all_prompts))
     |> assign(:current_system_prompt, default_system_prompt)
     |> assign(:show_prompt_viewer, false)
     |> assign(:viewing_prompt, nil)
     |> assign(:show_eval_viewer, false)
     |> assign(:viewing_eval, nil)
     |> assign(:screen_mode, "drawer")
     |> assign(:page_title, "AI Chat")
     |> PageMeta.assign_metadata(
       title: "AI Chat",
       description: "Chat with AI and manage conversations",
       url: "/dashboard/super_admin/ai-chat"
     )}
  end

  @impl true
  def handle_params(params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))

    # Handle conversation selection from URL
    case Map.get(params, "conversation_id") do
      nil ->
        {:noreply, socket}

      conversation_id ->
        case AI.get_conversation(conversation_id, socket.assigns.current_user.id) do
          nil ->
            {:noreply, push_navigate(socket, to: ~p"/dashboard/super_admin/ai-chat")}

          conversation ->
            messages = convert_db_messages_to_display(conversation.messages)

            {:noreply,
             socket
             |> assign(:current_conversation, conversation)
             |> assign(:messages, messages)}
        end
    end
  end

  @impl true
  def handle_event("new_conversation", _params, socket) do
    user_id = socket.assigns.current_user.id
    title = "New Conversation"

    case AI.create_conversation(user_id, title, socket.assigns.current_system_prompt) do
      {:ok, conversation} ->
        conversations = AI.list_conversations(user_id)

        {:noreply,
         socket
         |> assign(:conversations, conversations)
         |> assign(:current_conversation, conversation)
         |> assign(:messages, [])
         |> assign(:show_mobile_drawer, false)
         |> push_navigate(to: ~p"/dashboard/super_admin/ai-chat/#{conversation.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to create new conversation")}
    end
  end

  @impl true
  def handle_event("select_conversation", %{"id" => conversation_id}, socket) do
    {:noreply,
     socket
     |> assign(:show_mobile_drawer, false)
     |> push_navigate(to: ~p"/dashboard/super_admin/ai-chat/#{conversation_id}")}
  end

  @impl true
  def handle_event("select_model", %{"model" => short_name}, socket) do
    # Just update the selected model for future messages
    {:noreply, assign(socket, :selected_model, short_name)}
  end

  @impl true
  def handle_event("select_system_prompt", %{"prompt_name" => prompt_name}, socket) do
    # Handle the new prompt_name parameter - convert to get the actual prompt content
    {selected_prompt, current_system_prompt} =
      case prompt_name do
        "Default System" ->
          {"Default System", AI.get_default_system_prompt()}

        name ->
          case Enum.find(socket.assigns.available_prompts, &(&1.name == name)) do
            nil -> {"Default System", AI.get_default_system_prompt()}
            prompt -> {prompt.name, prompt.content}
          end
      end

    {:noreply,
     socket
     |> assign(:selected_system_prompt, selected_prompt)
     |> assign(:current_system_prompt, current_system_prompt)}
  end

  @impl true
  def handle_event("view_current_prompt", _params, socket) do
    viewing_prompt =
      case socket.assigns.selected_system_prompt do
        "Default System" ->
          %{
            name: "Default System",
            description: "Built-in default system prompt",
            content: socket.assigns.current_system_prompt,
            category: "system"
          }

        prompt_name ->
          case Enum.find(socket.assigns.available_prompts, &(&1.name == prompt_name)) do
            nil ->
              %{
                name: "Default System",
                description: "Built-in default system prompt",
                content: AI.get_default_system_prompt(),
                category: "system"
              }

            prompt ->
              prompt
          end
      end

    {:noreply,
     socket
     |> assign(:show_prompt_viewer, true)
     |> assign(:viewing_prompt, viewing_prompt)}
  end

  @impl true
  def handle_event("close_prompt_viewer", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_prompt_viewer, false)
     |> assign(:viewing_prompt, nil)}
  end

  @impl true
  def handle_event("set_screen_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :screen_mode, mode)}
  end

  @impl true
  def handle_event("select_eval", %{"eval" => eval_name}, socket) do
    {:noreply, assign(socket, :selected_eval, eval_name)}
  end

  @impl true
  def handle_event("view_current_eval", _params, socket) do
    viewing_eval =
      case socket.assigns.selected_eval do
        "No Eval Selected" ->
          nil

        name ->
          Enum.find(socket.assigns.available_evals, &(&1.name == name))
      end

    if viewing_eval do
      {:noreply,
       socket
       |> assign(:show_eval_viewer, true)
       |> assign(:viewing_eval, viewing_eval)}
    else
      {:noreply, put_flash(socket, :info, "No evaluation selected to view")}
    end
  end

  @impl true
  def handle_event("close_eval_viewer", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_eval_viewer, false)
     |> assign(:viewing_eval, nil)}
  end

  @impl true
  def handle_event("start_delete_conversation", %{"id" => conversation_id}, socket) do
    {:noreply, assign(socket, :deleting_conversation, conversation_id)}
  end

  @impl true
  def handle_event("confirm_delete_conversation", %{"id" => conversation_id}, socket) do
    user_id = socket.assigns.current_user.id

    case AI.delete_conversation(conversation_id, user_id) do
      {:ok, _} ->
        conversations = AI.list_conversations(user_id)

        socket =
          socket
          |> assign(:conversations, conversations)
          |> assign(:deleting_conversation, nil)

        # If we deleted the current conversation, redirect to main chat
        if socket.assigns.current_conversation &&
             to_string(socket.assigns.current_conversation.id) == conversation_id do
          {:noreply,
           socket
           |> assign(:current_conversation, nil)
           |> assign(:messages, [])
           |> assign(:show_mobile_drawer, false)
           |> push_navigate(to: ~p"/dashboard/super_admin/ai-chat")}
        else
          {:noreply, socket}
        end

      {:error, _} ->
        {:noreply,
         socket
         |> assign(:deleting_conversation, nil)
         |> put_flash(:error, "Failed to delete conversation")}
    end
  end

  @impl true
  def handle_event("cancel_delete_conversation", _params, socket) do
    {:noreply, assign(socket, :deleting_conversation, nil)}
  end

  @impl true
  def handle_event("start_edit_title", %{"id" => conversation_id}, socket) do
    conversation = Enum.find(socket.assigns.conversations, &(to_string(&1.id) == conversation_id))

    {:noreply,
     socket
     |> assign(:editing_title, conversation_id)
     |> assign(:new_title, conversation.title)}
  end

  @impl true
  def handle_event("cancel_edit_title", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_title, nil)
     |> assign(:new_title, "")}
  end

  @impl true
  def handle_event("save_title", %{"id" => conversation_id, "title" => title}, socket) do
    user_id = socket.assigns.current_user.id

    case AI.update_conversation_title(conversation_id, user_id, String.trim(title)) do
      {:ok, _conversation} ->
        conversations = AI.list_conversations(user_id)

        {:noreply,
         socket
         |> assign(:conversations, conversations)
         |> assign(:editing_title, nil)
         |> assign(:new_title, "")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update conversation title")}
    end
  end

  @impl true
  def handle_event("update_title_input", %{"title" => title}, socket) do
    {:noreply, assign(socket, :new_title, title)}
  end

  @impl true
  def handle_event("toggle_sidebar", _params, socket) do
    {:noreply, assign(socket, :sidebar_open, !socket.assigns.sidebar_open)}
  end

  @impl true
  def handle_event("show_mobile_history", _params, socket) do
    {:noreply, assign(socket, :show_mobile_drawer, true)}
  end

  @impl true
  def handle_event("hide_mobile_history", _params, socket) do
    {:noreply, assign(socket, :show_mobile_drawer, false)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    case socket.assigns.current_conversation do
      nil ->
        # Create new conversation if none exists
        handle_event("new_conversation", %{}, socket)
        |> case do
          {:noreply, updated_socket} ->
            # Send the message after creating the conversation
            send(self(), {:send_message_after_create, String.trim(message)})
            {:noreply, updated_socket}
        end

      conversation ->
        # Add user message to the chat display immediately
        user_message = %{
          role: "user",
          content: String.trim(message),
          timestamp: DateTime.utc_now()
        }

        messages = socket.assigns.messages ++ [user_message]

        # Set loading state and clear input
        socket =
          socket
          |> assign(:messages, messages)
          |> assign(:input_message, "")
          |> assign(:loading, true)
          |> assign(:streaming, true)
          |> assign(:current_stream, "")

        # Send async request to AI
        pid = self()
        user_id = socket.assigns.current_user.id

        Task.start(fn ->
          selected_model_api_id = get_model_api_id(socket.assigns.selected_model)

          case AI.stream_chat_in_conversation(
                 conversation.id,
                 user_id,
                 String.trim(message),
                 selected_model_api_id
               ) do
            {:ok, stream, _conversation, model_api_id} ->
              accumulated_response =
                stream
                |> Stream.map(&AI.extract_text_from_stream/1)
                |> Enum.reduce("", fn chunk, acc ->
                  new_acc = acc <> chunk
                  send(pid, {:stream_chunk, chunk})
                  new_acc
                end)

              send(pid, {:stream_complete, accumulated_response, conversation.id, model_api_id})

            {:error, error} ->
              send(pid, {:ai_error, error})
          end
        end)

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_message", _params, socket) do
    # Handle empty message - just return current state
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_input", %{"message" => message}, socket) do
    {:noreply, assign(socket, :input_message, message)}
  end

  @impl true
  def handle_info({:send_message_after_create, message}, socket) do
    # This handles sending a message after creating a new conversation
    handle_event("send_message", %{"message" => message}, socket)
  end

  @impl true
  def handle_info({:stream_chunk, chunk}, socket) do
    current_stream = socket.assigns.current_stream <> chunk
    {:noreply, assign(socket, :current_stream, current_stream)}
  end

  @impl true
  def handle_info({:stream_complete, full_response, conversation_id, model_api_id}, socket) do
    # Save the complete AI response to the database
    Task.start(fn ->
      AI.complete_streaming_conversation(conversation_id, full_response, model_api_id)
    end)

    # Check if this is the first AI response in the conversation (for auto-naming)
    # Only user message exists
    is_first_response = length(socket.assigns.messages) == 1

    # Add the complete streamed message to the chat display
    ai_message = %{
      role: "assistant",
      content: full_response,
      model: get_model_short_name(model_api_id),
      timestamp: DateTime.utc_now()
    }

    messages = socket.assigns.messages ++ [ai_message]

    # Auto-generate title if this is the first response
    if is_first_response and socket.assigns.current_conversation do
      user_message = List.first(socket.assigns.messages)

      if user_message && user_message.role == "user" do
        user_id = socket.assigns.current_user.id
        pid = self()

        Task.start(fn ->
          case AI.auto_generate_conversation_title(conversation_id, user_id, user_message.content) do
            {:ok, updated_conversation} ->
              send(pid, {:title_generated, updated_conversation})

            {:error, _reason} ->
              # Silently fail - the conversation will keep its default title
              :ok
          end
        end)
      end
    end

    # Update conversations list to reflect the updated timestamp
    user_id = socket.assigns.current_user.id
    conversations = AI.list_conversations(user_id)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:conversations, conversations)
     |> assign(:loading, false)
     |> assign(:streaming, false)
     |> assign(:current_stream, "")}
  end

  @impl true
  def handle_info({:ai_error, error}, socket) do
    # Add error message to the chat
    error_message = %{
      role: "system",
      content: "Error: #{inspect(error)}",
      timestamp: DateTime.utc_now()
    }

    messages = socket.assigns.messages ++ [error_message]

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:loading, false)
     |> assign(:streaming, false)
     |> assign(:current_stream, "")}
  end

  @impl true
  def handle_info({:title_generated, updated_conversation}, socket) do
    # Update the current conversation and conversations list with the new title
    user_id = socket.assigns.current_user.id
    conversations = AI.list_conversations(user_id)

    # Update current conversation if it matches
    current_conversation =
      if socket.assigns.current_conversation &&
           socket.assigns.current_conversation.id == updated_conversation.id do
        updated_conversation
      else
        socket.assigns.current_conversation
      end

    {:noreply,
     socket
     |> assign(:conversations, conversations)
     |> assign(:current_conversation, current_conversation)}
  end

  # Helper function to get default system prompt name
  defp get_default_system_prompt_name(prompts) do
    system_prompts = Enum.filter(prompts, &(&1.category == "system"))

    case system_prompts do
      [] -> "Default System"
      [first_prompt | _] -> first_prompt.name
    end
  end

  # Helper function to get default system prompt ID (kept for backward compatibility)
  # defp get_default_system_prompt_id(prompts) do
  #   system_prompts = Enum.filter(prompts, &(&1.category == "system"))

  #   case system_prompts do
  #     [] -> ""  # Empty string for "Default System"
  #     [first_prompt | _] -> to_string(first_prompt.id)
  #   end
  # end

  # Helper function to get default eval selection
  defp get_default_eval_selection(evals) do
    case evals do
      [] -> "No Eval Selected"
      [first_eval | _] -> first_eval.name
    end
  end

  # Helper function to convert between short names and API model IDs
  defp get_model_api_id(display_name) do
    Models.get_api_id(display_name)
  end

  # Helper function to convert from API model ID to short name
  defp get_model_short_name(api_id) do
    Models.get_display_name(api_id)
  end

  # Helper function to convert database messages to display format
  defp convert_db_messages_to_display(db_messages) do
    Enum.map(db_messages, fn msg ->
      %{
        role: Atom.to_string(msg.role),
        content: msg.content,
        model: if(msg.model, do: get_model_short_name(msg.model), else: nil),
        timestamp: msg.inserted_at
      }
    end)
  end

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 8)
  end

  defp truncate_title(title, max_length \\ 30) do
    if String.length(title) > max_length do
      String.slice(title, 0, max_length) <> "..."
    else
      title
    end
  end

  # Component for viewing prompt content
  defp prompt_viewer_content(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-xl font-semibold text-gray-900">{@prompt.name}</h2>
          <span class="inline-flex px-2 py-1 text-sm font-semibold rounded-full bg-gray-100 text-gray-800 mt-2">
            {String.replace(@prompt.category, "_", " ")
            |> String.split()
            |> Enum.map(&String.capitalize/1)
            |> Enum.join(" ")}
          </span>
        </div>
      </div>

      <%= if Map.get(@prompt, :description) do %>
        <div>
          <h3 class="text-sm font-medium text-gray-900 mb-2">Description</h3>
          <p class="text-sm text-gray-600">{@prompt.description}</p>
        </div>
      <% end %>

      <div>
        <h3 class="text-sm font-medium text-gray-900 mb-2">Prompt Content</h3>
        <div class="bg-gray-50 rounded-lg p-4 max-h-96 overflow-y-auto">
          <pre class="text-sm text-gray-800 whitespace-pre-wrap font-mono">{@prompt.content}</pre>
        </div>
      </div>

      <div class="flex justify-end pt-4 border-t border-gray-200">
        <.button variant="outline" phx-click="close_prompt_viewer" class="w-full">
          Close
        </.button>
      </div>
    </div>
    """
  end

  # Component for viewing eval content
  defp eval_viewer_content(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-start justify-between">
        <div>
          <h2 class="text-xl font-semibold text-gray-900">{@eval.name}</h2>
          <span class={[
            "inline-flex px-3 py-1 text-sm font-semibold rounded-full mt-2",
            if(@eval.is_active,
              do: "bg-green-100 text-green-800",
              else: "bg-red-100 text-red-800"
            )
          ]}>
            {if @eval.is_active, do: "Active", else: "Inactive"}
          </span>
        </div>
      </div>

      <%= if @eval.description do %>
        <div>
          <h3 class="text-sm font-medium text-gray-900 mb-2">Description</h3>
          <p class="text-sm text-gray-600">{@eval.description}</p>
        </div>
      <% end %>

      <div>
        <h3 class="text-sm font-medium text-gray-900 mb-2">Test Cases</h3>
        <div class="bg-gray-50 rounded-lg p-4 max-h-64 overflow-y-auto">
          <%= if map_size(@eval.test_cases) > 0 do %>
            <%= for {test_name, test_input} <- @eval.test_cases do %>
              <div class="mb-4 last:mb-0">
                <h4 class="text-sm font-medium text-gray-800 mb-1">{test_name}</h4>
                <p class="text-sm text-gray-600 bg-white p-2 rounded border">
                  {test_input}
                </p>
              </div>
            <% end %>
          <% else %>
            <p class="text-sm text-gray-500 italic">No test cases defined</p>
          <% end %>
        </div>
      </div>

      <%= if @eval.expected_outputs && map_size(@eval.expected_outputs) > 0 do %>
        <div>
          <h3 class="text-sm font-medium text-gray-900 mb-2">Expected Outputs</h3>
          <div class="bg-gray-50 rounded-lg p-4 max-h-64 overflow-y-auto">
            <%= for {test_name, expected_output} <- @eval.expected_outputs do %>
              <div class="mb-4 last:mb-0">
                <h4 class="text-sm font-medium text-gray-800 mb-1">{test_name}</h4>
                <p class="text-sm text-gray-600 bg-white p-2 rounded border">
                  {expected_output}
                </p>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%= if @eval.evaluation_criteria do %>
        <div>
          <h3 class="text-sm font-medium text-gray-900 mb-2">Evaluation Criteria</h3>
          <div class="bg-gray-50 rounded-lg p-4">
            <p class="text-sm text-gray-800 whitespace-pre-wrap">{@eval.evaluation_criteria}</p>
          </div>
        </div>
      <% end %>

      <div class="flex justify-end pt-4 border-t border-gray-200">
        <.button variant="outline" phx-click="close_eval_viewer" class="w-full">
          Close
        </.button>
      </div>
    </div>
    """
  end



  # Component for rendering conversation list (used in both sidebar and drawer)
  defp conversation_list(assigns) do
    ~H"""
    <%= if Enum.empty?(@conversations) do %>
      <div class="p-4 text-center text-gray-500">
        <Lucideicons.message_circle class="h-8 w-8 mx-auto mb-2 text-gray-300" />
        <p class="text-sm">No conversations yet</p>
      </div>
    <% else %>
      <div class="py-2 pr-2 space-y-1">
        <%= for conversation <- @conversations do %>
          <div class={[
            "group relative p-3 rounded-lg cursor-pointer transition-colors",
            if(@current_conversation && @current_conversation.id == conversation.id,
              do: "bg-gray-100 border border-gray-200",
              else: "hover:bg-gray-50"
            )
          ]}>
            <%= if @editing_title == to_string(conversation.id) do %>
              <form
                phx-submit="save_title"
                phx-value-id={conversation.id}
                class="flex items-center gap-1"
              >
                <input
                  type="text"
                  name="title"
                  value={@new_title}
                  phx-change="update_title_input"
                  class="flex-1 text-sm border border-gray-300 rounded px-2 py-1"
                  autofocus
                />
                <.button variant="outline" type="submit">
                  <Lucideicons.check class="h-4 w-4" />
                </.button>
                <.button variant="outline" phx-click="cancel_edit_title">
                  <Lucideicons.x class="h-4 w-4" />
                </.button>
              </form>
            <% else %>
              <div phx-click="select_conversation" phx-value-id={conversation.id} class="flex-1">
                <div class="flex items-start justify-between">
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium text-gray-900 truncate">
                      {truncate_title(conversation.title)}
                    </p>
                    <p class="text-xs text-gray-400 mt-1">
                      {format_timestamp(conversation.updated_at)}
                    </p>
                  </div>
                </div>
              </div>

              <div class="absolute top-4 right-2 opacity-0 group-hover:opacity-100 transition-opacity flex gap-1">
                <.button
                  phx-click="start_edit_title"
                  phx-value-id={conversation.id}
                  title="Edit title"
                >
                  <Lucideicons.pencil class="h-3 w-3" />
                </.button>

                <%= if @deleting_conversation == to_string(conversation.id) do %>
                  <.button
                    variant="destructive"
                    phx-click="confirm_delete_conversation"
                    phx-value-id={conversation.id}
                    title="Confirm delete"
                  >
                    <Lucideicons.check class="h-3 w-3" />
                  </.button>
                <% else %>
                  <.button
                    phx-click="start_delete_conversation"
                    phx-value-id={conversation.id}
                    title="Delete conversation"
                  >
                    <Lucideicons.trash_2 class="h-3 w-3" />
                  </.button>
                <% end %>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-[calc(100vh-90px)]">
      <div class={[
        "hidden lg:flex bg-white transition-all duration-300 bg-blue-100 flex-shrink-0",
        if(@sidebar_open, do: "w-80", else: "w-0 overflow-hidden")
      ]}>
        <div class="h-full flex flex-col w-full">
          <div class="flex-1 overflow-y-auto">
            <.conversation_list
              conversations={@conversations}
              current_conversation={@current_conversation}
              editing_title={@editing_title}
              new_title={@new_title}
              deleting_conversation={@deleting_conversation}
            />
          </div>
        </div>
      </div>

      <.drawer
        show={@show_mobile_drawer}
        on_cancel={JS.push("hide_mobile_history")}
        direction="bottom"
      >
        <.drawer_header>
          <.drawer_title>Chat History</.drawer_title>
          <.drawer_description>Select a conversation to continue</.drawer_description>
        </.drawer_header>
        <.drawer_content>
          <div class="mb-4">
            <.button phx-click="new_conversation" class="w-full bg-black hover:bg-gray-800 text-white">
              <Lucideicons.plus class="h-4 w-4 mr-2" /> New Conversation
            </.button>
          </div>
          <.conversation_list
            conversations={@conversations}
            current_conversation={@current_conversation}
            editing_title={@editing_title}
            new_title={@new_title}
            deleting_conversation={@deleting_conversation}
          />
        </.drawer_content>
      </.drawer>

      <div class="flex-1 flex flex-col min-w-0">
        <.header class="ml-2">
          <div class="flex items-center">
            <button
              phx-click="toggle_sidebar"
              class="hidden lg:flex -ml-2 p-2 text-gray-400 hover:text-gray-600 rounded-lg"
            >
              <Lucideicons.panel_left class="h-5 w-5" />
            </button>
            <div>
              AI Chat
            </div>
          </div>
          <:subtitle>
            <%= if @current_conversation do %>
              {truncate_title(@current_conversation.title, 50)}
            <% end %>
          </:subtitle>
          <:actions>
            <div class="flex items-center gap-3">
              <.model_selector
                selected_model={@selected_model}
                on_change="select_model"
                class="w-[140px]"
              />
              <.button phx-click="new_conversation" class="bg-black hover:bg-gray-800">
                <Lucideicons.plus class="h-4 w-4 mr-2" /> New Chat
              </.button>
            </div>
          </:actions>
        </.header>

        <div class="mt-4 mb-4 space-y-3">
          <div class="flex items-center gap-2 h-10">
            <.prompt_selector
              available_prompts={@available_prompts}
              selected_prompt={@selected_system_prompt}
              on_change="select_system_prompt"
              class="w-[200px]"
              id="system-prompt-select"
            />
            <.button
              variant="outline"
              size="sm"
              class="h-full"
              phx-click="view_current_prompt"
              title="View current system prompt"
            >
              <Lucideicons.eye class="h-4 w-4" />
            </.button>
          </div>

          <div class="flex items-center gap-2 h-10">
            <.eval_selector
              available_evals={@available_evals}
              selected_eval={@selected_eval}
              on_change="select_eval"
              class="w-[200px]"
              id="chat-eval-select"
              show_default={true}
              show_all_option={false}
            />
            <.button
              variant="outline"
              size="sm"
              class="h-full"
              phx-click="view_current_eval"
              title="View current evaluation"
              disabled={@selected_eval == "No Eval Selected"}
            >
              <Lucideicons.eye class="h-4 w-4" />
            </.button>
          </div>
        </div>

        <div class="flex-1 bg-white rounded-lg shadow-sm border border-gray-200 flex flex-col min-h-0">
          <div class="flex-1 overflow-y-auto p-4 space-y-4" id="chat-messages">
            <%= if Enum.empty?(@messages) do %>
              <div class="text-center text-gray-500 mt-8">
                <Lucideicons.message_circle class="h-12 w-12 mx-auto mb-2 text-gray-300" />
                <p>
                  <%= if @current_conversation do %>
                    Start chatting in this conversation!
                  <% else %>
                    Create a new conversation to start chatting with Claude!
                  <% end %>
                </p>
                <p class="text-sm mt-2">
                  Current model: <span class="font-medium">{@selected_model}</span>
                </p>
                <p class="text-xs text-gray-400 mt-1">
                  System prompt: <span class="font-medium">{@selected_system_prompt}</span>
                </p>
                <p class="text-xs text-gray-400 mt-1">
                  Evaluation: <span class="font-medium">{@selected_eval}</span>
                </p>
              </div>
            <% else %>
              <%= for message <- @messages do %>
                <div class={[
                  "flex",
                  case message.role do
                    "user" -> "justify-end"
                    "assistant" -> "justify-start"
                    "system" -> "justify-center"
                  end
                ]}>
                  <div class={[
                    "max-w-[70%] rounded-lg px-4 py-2",
                    case message.role do
                      "user" -> "bg-black text-white"
                      "assistant" -> "bg-gray-100 text-gray-900"
                      "system" -> "bg-red-100 text-red-800 text-sm"
                    end
                  ]}>
                    <div class="flex items-center gap-2">
                      <%= case message.role do %>
                        <% "user" -> %>
                          <Lucideicons.user class="h-4 w-4" />
                          <span class="text-sm font-medium">You</span>
                        <% "assistant" -> %>
                          <Lucideicons.bot class="h-4 w-4" />
                          <span class="text-sm font-medium">Claude</span>
                          <%= if message.model do %>
                            <span class="text-xs bg-gray-200 text-gray-700 px-2 py-0.5 rounded-full">
                              {message.model}
                            </span>
                          <% end %>
                        <% "system" -> %>
                          <Lucideicons.triangle_alert class="h-4 w-4" />
                          <span class="text-sm font-medium">System</span>
                      <% end %>
                      <span class="text-xs opacity-70">
                        {format_timestamp(message.timestamp)}
                      </span>
                    </div>
                    <div class="break-words">
                      <%= case message.role do %>
                        <% "assistant" -> %>
                          <div class="mt-1 prose prose-md max-w-none prose-gray prose-headings:text-gray-900 prose-code:text-gray-100 prose-code:bg-gray-800 prose-code:px-1.5 prose-code:py-1 prose-code:rounded prose-code:text-sm prose-code:font-medium prose-pre:bg-gray-900 prose-pre:text-gray-100 prose-pre:text-sm prose-pre:p-4 prose-pre:rounded-lg prose-blockquote:border-l-gray-300">
                            {Markdown.to_html(message.content)}
                          </div>
                        <% _ -> %>
                          <div class="whitespace-pre-line -mt-5">
                            {message.content}
                          </div>
                      <% end %>
                    </div>
                  </div>
                </div>
              <% end %>
            <% end %>

            <%= if @streaming do %>
              <div class="flex justify-start">
                <div class="bg-gray-100 rounded-lg px-4 py-2 max-w-[70%]">
                  <div class="flex items-center gap-2 mb-1">
                    <Lucideicons.bot class="h-4 w-4" />
                    <span class="text-sm font-medium">Claude</span>
                    <span class="text-xs bg-gray-200 text-gray-700 px-2 py-0.5 rounded-full">
                      {@selected_model}
                    </span>
                  </div>
                  <%= if @current_stream != "" do %>
                    <div class="break-words">
                      <div class="mt-1 prose prose-md max-w-none prose-gray prose-headings:text-gray-900 prose-code:text-gray-100 prose-code:bg-gray-800 prose-code:px-1.5 prose-code:py-1 prose-code:rounded prose-code:text-sm prose-code:font-medium prose-pre:bg-gray-900 prose-pre:text-gray-100 prose-pre:text-sm prose-pre:p-4 prose-pre:rounded-lg prose-blockquote:border-l-gray-300">
                        {Markdown.to_html(@current_stream)}
                      </div>
                    </div>
                  <% end %>
                  <div class="flex items-center gap-1 mt-4">
                    <div
                      class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                      style="animation-delay: 0.1s"
                    />
                    <div
                      class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                      style="animation-delay: 0.2s"
                    />
                    <div
                      class="w-2 h-2 bg-gray-400 rounded-full animate-bounce"
                      style="animation-delay: 0.3s"
                    />
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <div class="border-t border-gray-200 px-4 pb-2 flex-shrink-0">
            <.form for={%{}} as={:chat_form} phx-submit="send_message" class="flex items-center gap-3">
              <.button
                type="button"
                phx-click="show_mobile_history"
                class="lg:hidden mt-2"
                title="Chat History"
              >
                <Lucideicons.history class="h-4 w-4" />
              </.button>

              <div class="flex-1">
                <.input
                  type="text"
                  name="message"
                  value={@input_message}
                  placeholder="Type your message to Claude..."
                  phx-change="update_input"
                  disabled={@loading}
                  autofocus
                />
              </div>
              <.button type="submit" class="mt-2" disabled={@loading || @input_message == ""}>
                <%= if @loading do %>
                  <Lucideicons.loader class="h-4 w-4 animate-spin" />
                <% else %>
                  <Lucideicons.send class="h-4 w-4" />
                <% end %>
              </.button>
            </.form>
          </div>
        </div>
      </div>
    </div>

    <.dialog_drawer_wrapper
      :if={@show_prompt_viewer && @viewing_prompt}
      id="prompt-viewer-wrapper"
      show={@show_prompt_viewer}
      hook="DialogDrawerMode"
      mode={@screen_mode}
      on_cancel={JS.push("close_prompt_viewer")}
      name="System Prompt Details"
      description="View the current system prompt content"
    >
      <.prompt_viewer_content prompt={@viewing_prompt} />
    </.dialog_drawer_wrapper>

    <.dialog_drawer_wrapper
      :if={@show_eval_viewer && @viewing_eval}
      id="eval-viewer-wrapper"
      show={@show_eval_viewer}
      hook="DialogDrawerMode"
      mode={@screen_mode}
      on_cancel={JS.push("close_eval_viewer")}
      name="Evaluation Details"
      description="View the current evaluation test cases and criteria"
    >
      <.eval_viewer_content eval={@viewing_eval} />
    </.dialog_drawer_wrapper>

    <script>
      window.addEventListener('phx:update', () => {
        const chatMessages = document.getElementById('chat-messages');
        if (chatMessages) {
          chatMessages.scrollTop = chatMessages.scrollHeight;
        }
      });
    </script>
    """
  end
end
