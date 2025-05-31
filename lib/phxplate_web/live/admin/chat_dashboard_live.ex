defmodule PhxplateWeb.Admin.ChatDashboardLive do
  @moduledoc """
  LiveView for super admin chat management.

  This view provides functionality for super admins to manage chat sessions,
  including viewing and responding to messages, closing sessions, and monitoring
  active chats. It features real-time updates via PubSub subscriptions.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.Chat
  alias PhxplateWeb.PageMeta
  import PhxplateWeb.Components.UI.Drawer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Phxplate.PubSub, "admin:chat")
    end

    {:ok,
     socket
     |> stream_configure(:messages, dom_id: &"msg-#{&1.id}")
     |> stream(:messages, [])
     |> assign(
       selected_session: nil,
       current_message: "",
       show_drawer: false
     )
     |> PageMeta.assign_metadata(
       title: "Chat Management",
       description: "Manage customer support chat sessions",
       url: "/dashboard/super_admin/chat"
     )
     |> load_sessions(1)}
  end

  defp load_sessions(socket, page) do
    per_page = 10

    # Get total count for pagination
    total_sessions = Chat.count_sessions()
    total_pages = max(1, ceil(total_sessions / per_page))

    # Get paginated sessions
    sessions = Chat.list_sessions(page: page, per_page: per_page)

    socket
    |> assign(:active_sessions, sessions)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:per_page, per_page)
  end

  @impl true
  def handle_event("select_session", %{"id" => session_id, "is_mobile" => "true"}, socket) do
    # Mobile view - show drawer
    select_session(session_id, socket, true)
  end

  def handle_event("select_session", %{"id" => session_id}, socket) do
    # Desktop view - don't show drawer
    select_session(session_id, socket, false)
  end

  def handle_event("close_drawer", _params, socket) do
    {:noreply, assign(socket, show_drawer: false)}
  end

  def handle_event("send_message", %{"message" => %{"content" => content}}, socket) do
    if String.trim(content) != "" && socket.assigns.selected_session do
      session = socket.assigns.selected_session

      attrs = %{
        content: content,
        sender_type: "admin",
        chat_session_id: session.id,
        user_id: socket.assigns.current_user.id
      }

      case Chat.create_message(attrs) do
        {:ok, _message} ->
          {:noreply, assign(socket, current_message: "")}

        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_event("update_message", %{"message" => %{"content" => content}}, socket) do
    {:noreply, assign(socket, current_message: content)}
  end

  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    {:noreply, load_sessions(socket, page)}
  end

  def handle_event("close_session", _params, socket) do
    if socket.assigns.selected_session do
      session = socket.assigns.selected_session

      case Chat.close_session(session) do
        {:ok, _session} ->
          {:noreply, socket}

        {:error, _changeset} ->
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  # Helper function to select a session
  defp select_session(session_id, socket, show_drawer) do
    session_id = String.to_integer(session_id)
    session = Chat.get_session_with_messages(session_id)

    if session do
      messages =
        Enum.map(session.messages, fn msg ->
          %{
            id: msg.id,
            content: msg.content,
            sender_type: msg.sender_type,
            inserted_at: msg.inserted_at
          }
        end)

      {:noreply,
       socket
       |> stream(:messages, messages, reset: true)
       |> assign(selected_session: session, show_drawer: show_drawer)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_session, session}, socket) do
    active_sessions = [session | socket.assigns.active_sessions]
    {:noreply, assign(socket, active_sessions: active_sessions)}
  end

  def handle_info({:new_message, message}, socket) do
    # Update messages if this is for the selected session
    if socket.assigns.selected_session &&
         message.chat_session_id == socket.assigns.selected_session.id do
      formatted_message = %{
        id: message.id,
        content: message.content,
        sender_type: message.sender_type,
        inserted_at: message.inserted_at
      }

      {:noreply, stream_insert(socket, :messages, formatted_message)}
    else
      # Update the session in the list to show there's a new message
      {:noreply, socket}
    end
  end

  def handle_info({:session_closed, closed_session}, socket) do
    # Update the session status in the active sessions list
    updated_sessions =
      Enum.map(socket.assigns.active_sessions, fn session ->
        if session.id == closed_session.id do
          %{session | status: "closed"}
        else
          session
        end
      end)

    # If this was the selected session, update it too
    selected_session =
      if socket.assigns.selected_session &&
           socket.assigns.selected_session.id == closed_session.id do
        %{socket.assigns.selected_session | status: "closed"}
      else
        socket.assigns.selected_session
      end

    {:noreply,
     assign(socket, active_sessions: updated_sessions, selected_session: selected_session)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Chat Management
        <:subtitle>Manage customer support chat sessions</:subtitle>
      </.header>

      <div
        class="grid grid-cols-1 lg:grid-cols-3 lg:gap-8 mt-4 h-[calc(100vh-200px)]"
        id="chat-dashboard"
        phx-hook="ChatDashboard"
      >
        <!-- Sessions List (Left Side) -->
        <div class="h-[calc(100vh-200px)] col-span-1">
          <h2 class="text-xl font-semibold mb-4">Chat Sessions</h2>

          <%= if Enum.empty?(@active_sessions) do %>
            <div class="text-center py-4">
              <p class="text-sm text-gray-500">No active chat sessions</p>
            </div>
          <% else %>
            <%= for session <- @active_sessions do %>
              <div class={"cursor-pointer p-3 rounded-md hover:bg-gray-50 relative #{if @selected_session && @selected_session.id == session.id, do: "bg-gray-100 border-l-4 border-blue-500", else: ""}"}>
                <!-- Desktop click handler (hidden on mobile) -->
                <div
                  class="hidden md:block h-full w-full absolute inset-0"
                  phx-click="select_session"
                  phx-value-id={session.id}
                >
                </div>
                <!-- Mobile click handler (hidden on desktop) -->
                <div
                  class="md:hidden h-full w-full absolute inset-0"
                  phx-click="select_session"
                  phx-value-id={session.id}
                  phx-value-is_mobile="true"
                >
                </div>
                <!-- Session content -->
                <div class="flex justify-between items-center">
                  <h4 class="text-sm font-medium text-gray-900">
                    <%= if session.user_id do %>
                      {session.user.email}
                    <% else %>
                      {session.anonymous_name}
                    <% end %>
                  </h4>
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{if session.status == "active", do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800"}"}>
                    {session.status}
                  </span>
                </div>
                <div class="mt-1">
                  <p class="text-xs text-gray-500">
                    Started: {Calendar.strftime(session.started_at, "%B %d, %Y at %H:%M")}
                  </p>
                </div>
              </div>
            <% end %>
          <% end %>
          <%= if @total_pages > 1 do %>
            <div class="mt-4 mb-2">
              <.pagination class="justify-center">
                <.pagination_content>
                  <%= if @page > 1 do %>
                    <.pagination_item>
                      <.pagination_link phx-click="paginate" phx-value-page={@page - 1}>
                        <Lucideicons.chevron_left class="h-4 w-4" />
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>

                  <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                    <.pagination_item active={page_num == @page}>
                      <.pagination_link phx-click="paginate" phx-value-page={page_num}>
                        {page_num}
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>

                  <%= if @page < @total_pages do %>
                    <.pagination_item>
                      <.pagination_link phx-click="paginate" phx-value-page={@page + 1}>
                        <Lucideicons.chevron_right class="h-4 w-4" />
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>
                </.pagination_content>
              </.pagination>
            </div>
          <% end %>
        </div>

        <!-- Chat Content (Right Side) -->
        <div class="lg:col-span-2 h-[calc(100vh-200px)] overflow-hidden">
          <%= if @selected_session do %>
            <div class="bg-white overflow-hidden shadow rounded-lg h-full flex flex-col">
              <div class="px-4 py-5 sm:px-6 flex justify-between items-center border-b">
                <div>
                  <h3 class="text-lg leading-6 font-medium text-gray-900">
                    <%= if @selected_session.user_id do %>
                      {@selected_session.user.email}
                    <% else %>
                      {@selected_session.anonymous_name}
                    <% end %>
                  </h3>
                  <%= if @selected_session.anonymous_email do %>
                    <p class="mt-1 max-w-2xl text-sm text-gray-500">
                      {@selected_session.anonymous_email}
                    </p>
                  <% end %>
                </div>
                <div class="flex items-center space-x-3">
                  <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{if @selected_session.status == "active", do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800"}"}>
                    {@selected_session.status}
                  </span>
                  <%= if @selected_session.status == "active" do %>
                    <.button phx-click="close_session" size="sm" variant="destructive">
                      Close Session
                    </.button>
                  <% end %>
                </div>
              </div>
              <div class="flex-1 overflow-hidden flex flex-col">
                <div
                  class="chat-messages flex-1 overflow-y-auto p-4"
                  id="desktop-chat-messages"
                  phx-hook="ScrollChat"
                >
                  <div
                    id="messages-desktop"
                    phx-update="stream"
                    phx-stream="messages"
                    class="space-y-3"
                  >
                    <%= for {msg_id, message} <- @streams.messages do %>
                      <div
                        class={"flex #{if message.sender_type == "admin", do: "justify-end", else: "justify-start"}"}
                        id={msg_id}
                      >
                        <div class={"max-w-3/4 px-4 py-2 rounded-lg #{if message.sender_type == "admin", do: "bg-blue-100", else: "bg-gray-100"}"}>
                          <div class="text-sm">{message.content}</div>
                          <div class="text-xs text-gray-500 mt-1">
                            {Calendar.strftime(message.inserted_at, "%H:%M")}
                          </div>
                        </div>
                      </div>
                    <% end %>
                  </div>
                </div>

                <%= if @selected_session.status == "active" do %>
                  <div class="border-t p-4">
                    <.form
                      for={%{}}
                      as={:message}
                      phx-submit="send_message"
                      phx-change="update_message"
                    >
                      <div class="flex space-x-2">
                        <input
                          type="text"
                          name="message[content]"
                          value={@current_message}
                          placeholder="Type your message..."
                          class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                        />
                        <.button type="submit">Send</.button>
                      </div>
                    </.form>
                  </div>
                <% end %>
              </div>
            </div>
          <% else %>
            <div class="bg-white overflow-hidden shadow rounded-lg h-full flex flex-col justify-center items-center">
              <div class="text-center p-8">
                <svg
                  class="mx-auto h-16 w-16 text-gray-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                  xmlns="http://www.w3.org/2000/svg"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M8 10h.01M12 10h.01M16 10h.01M9 16H5a2 2 0 01-2-2V6a2 2 0 012-2h14a2 2 0 012 2v8a2 2 0 01-2 2h-5l-5 5v-5z"
                  >
                  </path>
                </svg>
                <h3 class="mt-4 text-lg font-medium text-gray-900">No chat session selected</h3>
                <p class="mt-2 text-base text-gray-500 max-w-md">
                  Select a chat session from the list to view and respond to messages.
                </p>
              </div>
            </div>
          <% end %>
        </div>
      </div>

    <!-- Mobile Drawer -->
      <.drawer show={@show_drawer} on_cancel={JS.push("close_drawer")}>
        <.drawer_header>
          <.drawer_title>
            <%= if @selected_session do %>
              <%= if @selected_session.user_id do %>
                {@selected_session.user.email}
              <% else %>
                {@selected_session.anonymous_name}
              <% end %>
            <% else %>
              Chat Session
            <% end %>
          </.drawer_title>
          <%= if @selected_session && @selected_session.anonymous_email do %>
            <.drawer_description>
              {@selected_session.anonymous_email}
            </.drawer_description>
          <% end %>
        </.drawer_header>

        <%= if @selected_session do %>
          <.drawer_content>
            <div class="flex justify-between items-center mb-4">
              <span class={"inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{if @selected_session.status == "active", do: "bg-green-100 text-green-800", else: "bg-gray-100 text-gray-800"}"}>
                {@selected_session.status}
              </span>
              <%= if @selected_session.status == "active" do %>
                <.button phx-click="close_session" size="sm" variant="destructive">
                  Close Session
                </.button>
              <% end %>
            </div>

            <div
              class="chat-messages h-96 overflow-y-auto mb-4"
              id="mobile-chat-messages"
              phx-hook="ScrollChat"
            >
              <div id="messages-mobile" phx-update="stream" phx-stream="messages" class="space-y-3">
                <%= for {msg_id, message} <- @streams.messages do %>
                  <div
                    class={"flex #{if message.sender_type == "admin", do: "justify-end", else: "justify-start"}"}
                    id={msg_id}
                  >
                    <div class={"max-w-3/4 px-4 py-2 rounded-lg #{if message.sender_type == "admin", do: "bg-blue-100", else: "bg-gray-100"}"}>
                      <div class="text-sm">{message.content}</div>
                      <div class="text-xs text-gray-500 mt-1">
                        {Calendar.strftime(message.inserted_at, "%H:%M")}
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>

            <%= if @selected_session.status == "active" do %>
              <.form
                for={%{}}
                as={:message}
                phx-submit="send_message"
                phx-change="update_message"
                class="mt-4"
              >
                <div class="flex space-x-2">
                  <input
                    type="text"
                    name="message[content]"
                    value={@current_message}
                    placeholder="Type your message..."
                    class="flex-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
                  />
                  <.button type="submit">Send</.button>
                </div>
              </.form>
            <% end %>
          </.drawer_content>
        <% end %>
      </.drawer>
    </div>
    """
  end
end
