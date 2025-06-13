defmodule PhxplateWeb.Dashboard.SuperAdmin.AiChatLive do
  @moduledoc """
  LiveView for testing the AI Chat functionality with persistence.

  This view allows super admins to test the Anthropic Claude integration
  with a chat interface that persists conversations and messages.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.AI
  alias PhxplateWeb.PageMeta
  alias PhxplateWeb.Components.Markdown
  import PhxplateWeb.Components.UI.Drawer

  @system_prompt """
  You are a helpful AI assistant integrated into a Phoenix application.
  You provide clear, concise, and accurate responses while maintaining a professional tone.
  When discussing code or technical topics, you provide practical examples and explanations.
  You are knowledgeable about Elixir, Phoenix, LiveView, and web development in general.
  Keep your responses focused and relevant to the user's questions.
  """

  # Available Claude models with simplified names
  @available_models [
    {"Haiku 3", "claude-3-haiku-20240307"},
    {"Sonnet 3", "claude-3-sonnet-20240229"},
    {"Opus 3", "claude-3-opus-20240229"},
    {"Haiku 3.5", "claude-3-5-haiku-20241022"},
    {"Sonnet 3.5", "claude-3-5-sonnet-20241022"},
    {"Sonnet 3.7", "claude-3-7-sonnet-20250219"},
    {"Sonnet 4", "claude-sonnet-4-20250514"},
    {"Opus 4", "claude-opus-4-20250514"}
  ]

  @default_model "Haiku 3.5"

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    conversations = AI.list_conversations(user_id)

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
     |> assign(:selected_model, @default_model)
     |> assign(:available_models, @available_models)
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

    case AI.create_conversation(user_id, title, @system_prompt) do
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
          case AI.stream_chat_in_conversation(conversation.id, user_id, String.trim(message), selected_model_api_id) do
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

    # Add the complete streamed message to the chat display
    ai_message = %{
      role: "assistant",
      content: full_response,
      model: get_model_short_name(model_api_id),
      timestamp: DateTime.utc_now()
    }

    messages = socket.assigns.messages ++ [ai_message]

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

  # Helper function to convert between short names and API model IDs
  defp get_model_api_id(short_name) do
    model_mapping = %{
      "Haiku 3" => "claude-3-haiku-20240307",
      "Sonnet 3" => "claude-3-sonnet-20240229",
      "Opus 3" => "claude-3-opus-20240229",
      "Haiku 3.5" => "claude-3-5-haiku-20241022",
      "Sonnet 3.5" => "claude-3-5-sonnet-20241022",
      "Sonnet 3.7" => "claude-3-7-sonnet-20250219",
      "Sonnet 4" => "claude-sonnet-4-20250514",
      "Opus 4" => "claude-opus-4-20250514"
    }

    Map.get(model_mapping, short_name, short_name)
  end

  # Helper function to convert from API model ID to short name
  defp get_model_short_name(api_id) do
    model_mapping = %{
      "claude-3-haiku-20240307" => "Haiku 3",
      "claude-3-sonnet-20240229" => "Sonnet 3",
      "claude-3-opus-20240229" => "Opus 3",
      "claude-3-5-haiku-20241022" => "Haiku 3.5",
      "claude-3-5-sonnet-20241022" => "Sonnet 3.5",
      "claude-3-7-sonnet-20250219" => "Sonnet 3.7",
      "claude-sonnet-4-20250514" => "Sonnet 4",
      "claude-opus-4-20250514" => "Opus 4"
    }

    Map.get(model_mapping, api_id, api_id)
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

    <!-- Action buttons (shown on hover) -->
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
      <!-- Desktop Sidebar -->
      <div class={[
        "hidden md:flex bg-white transition-all duration-300 bg-blue-100 flex-shrink-0",
        if(@sidebar_open, do: "w-80", else: "w-0 overflow-hidden")
      ]}>
        <div class="h-full flex flex-col w-full">
          <!-- Conversations List -->
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

    <!-- Mobile History Drawer -->
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

    <!-- Main Chat Area -->
      <div class="flex-1 flex flex-col min-w-0">
        <.header class="ml-2">
          <div class="flex items-center">
            <!-- Desktop sidebar toggle -->
            <button
              phx-click="toggle_sidebar"
              class="hidden md:flex -ml-2 p-2 text-gray-400 hover:text-gray-600 rounded-lg"
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
            <!-- Model Selector -->
            <div class="flex items-center gap-3">
              <div class="flex items-center gap-2">
                <form phx-change="select_model">
                  <.select :let={select} id="model-select" name="model" value={@selected_model}>
                    <.select_trigger builder={select} class="w-[140px]" />
                    <.select_content class="w-[140px]" builder={select}>
                      <%= for {name, _api_id} <- @available_models do %>
                        <.select_item builder={select} value={name} label={name}>
                          {name}
                        </.select_item>
                      <% end %>
                    </.select_content>
                  </.select>
                </form>
              </div>
              <.button phx-click="new_conversation" class="bg-black hover:bg-gray-800">
                <Lucideicons.plus class="h-4 w-4 mr-2" /> New Chat
              </.button>
            </div>
          </:actions>
        </.header>

        <div class="flex-1 mt-4 bg-white rounded-lg shadow-sm border border-gray-200 flex flex-col min-h-0">
          <!-- Chat Messages Area -->
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
                            <%= Markdown.to_html(message.content) %>
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
                        <%= Markdown.to_html(@current_stream) %>
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

          <!-- Input Area -->
          <div class="border-t border-gray-200 px-4 pb-2 flex-shrink-0">
            <.form for={%{}} as={:chat_form} phx-submit="send_message" class="flex items-center gap-3">
              <!-- Mobile History Button -->
              <.button
                type="button"
                phx-click="show_mobile_history"
                class="md:hidden mt-2"
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

    <script>
      // Auto-scroll to bottom when new messages arrive
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
