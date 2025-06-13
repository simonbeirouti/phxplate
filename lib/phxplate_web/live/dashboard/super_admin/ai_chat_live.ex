defmodule PhxplateWeb.Dashboard.SuperAdmin.AiChatLive do
  @moduledoc """
  LiveView for testing the AI Chat functionality.

  This view allows super admins to test the Anthropic Claude integration
  with a simple chat interface.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.AI
  alias PhxplateWeb.PageMeta

  @system_prompt """
  You are a helpful AI assistant integrated into a Phoenix application.
  You provide clear, concise, and accurate responses while maintaining a professional tone.
  When discussing code or technical topics, you provide practical examples and explanations.
  You are knowledgeable about Elixir, Phoenix, LiveView, and web development in general.
  Keep your responses focused and relevant to the user's questions.
  """

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:input_message, "")
     |> assign(:loading, false)
     |> assign(:streaming, false)
     |> assign(:current_stream, "")
     |> assign(:page_title, "AI Chat")
     |> PageMeta.assign_metadata(
       title: "AI Chat",
       description: "Test the AI Chat functionality",
       url: "/dashboard/super_admin/ai-chat"
     )}
  end

  @impl true
  def handle_params(_params, url, socket) do
    uri = URI.parse(url)
    socket = update(socket, :layout_data, &Map.put(&1, :current_path, uri.path))
    {:noreply, socket}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) when message != "" do
    # Add user message to the chat
    user_message = %{role: "user", content: String.trim(message), timestamp: DateTime.utc_now()}
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
    Task.start(fn ->
      case AI.stream_chat(message, @system_prompt) do
        {:ok, stream} ->
          stream
          |> Stream.each(fn chunk ->
            send(pid, {:stream_chunk, chunk})
          end)
          |> Stream.run()
          send(pid, :stream_complete)
        {:error, error} ->
          send(pid, {:ai_error, error})
      end
    end)

    {:noreply, socket}
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
  def handle_event("clear_chat", _params, socket) do
    {:noreply, assign(socket, :messages, [])}
  end

  @impl true
  def handle_info({:stream_chunk, chunk}, socket) do
    current_stream = socket.assigns.current_stream <> chunk
    {:noreply, assign(socket, :current_stream, current_stream)}
  end

  @impl true
  def handle_info(:stream_complete, socket) do
    # Add the complete streamed message to the chat
    ai_message = %{
      role: "assistant",
      content: socket.assigns.current_stream,
      timestamp: DateTime.utc_now()
    }
    messages = socket.assigns.messages ++ [ai_message]

    {:noreply,
     socket
     |> assign(:messages, messages)
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

  defp format_timestamp(timestamp) do
    timestamp
    |> DateTime.to_time()
    |> Time.to_string()
    |> String.slice(0, 8)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 flex flex-col h-[calc(100vh-90px)]">
      <.header>
        AI Chat
        <:subtitle>Chat with Claude</:subtitle>
        <:actions>
          <.button
            phx-click="clear_chat"
            data-confirm="Are you sure you want to clear the chat?"
            class="bg-red-600 hover:bg-red-700"
          >
            Clear Chat
          </.button>
        </:actions>
      </.header>

      <div class="flex-1 mt-4 bg-white rounded-lg shadow-sm border border-gray-200 flex flex-col min-h-0">
        <!-- Chat Messages Area -->
        <div class="flex-1 overflow-y-auto p-4 space-y-4" id="chat-messages">
          <%= if Enum.empty?(@messages) do %>
            <div class="text-center text-gray-500 mt-8">
              <Lucideicons.message_circle class="h-12 w-12 mx-auto mb-2 text-gray-300" />
              <p>No messages yet. Start a conversation with Claude!</p>
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
                      <% "system" -> %>
                        <Lucideicons.triangle_alert class="h-4 w-4" />
                        <span class="text-sm font-medium">System</span>
                    <% end %>
                    <span class="text-xs opacity-70">
                      {format_timestamp(message.timestamp)}
                    </span>
                  </div>
                  <div class="whitespace-pre-line break-words -mt-5">
                    {message.content}
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
                </div>
                <%= if @current_stream != "" do %>
                  <div class="whitespace-pre-line break-words -mt-5">
                    {@current_stream}
                  </div>
                <% end %>
                <div class="flex items-center gap-1 mt-4">
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.1s" />
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.2s" />
                  <div class="w-2 h-2 bg-gray-400 rounded-full animate-bounce" style="animation-delay: 0.3s" />
                </div>
              </div>
            </div>
          <% end %>
        </div>

        <!-- Input Area -->
        <div class="border-t border-gray-200 p-4 flex-shrink-0">
          <.form for={%{}} as={:chat_form} phx-submit="send_message" class="flex items-end gap-3">
            <div class="flex-1">
              <.input
                type="text"
                name="message"
                value={@input_message}
                placeholder="Type your message to Claude..."
                phx-change="update_input"
                disabled={@loading}
                class="w-full h-10"
                autofocus
              />
            </div>
            <.button
              type="submit"
              disabled={@loading || @input_message == ""}
              class="h-10 px-4 flex items-center justify-center"
            >
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
