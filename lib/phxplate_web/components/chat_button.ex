defmodule PhxplateWeb.Components.ChatButton do
  @moduledoc """
  Provides the chat button and modal component for the application.

  This component renders a chat button in the bottom-right corner of the application
  that opens a chat modal when clicked. It allows users to communicate with support
  staff in real-time.
  """
  use PhxplateWeb, :html

  attr :current_user, :any, default: nil, doc: "The current user (if authenticated)"
  attr :current_path, :string, default: nil, doc: "The current path of the request"

  @doc """
  Renders the chat button and modal component.

  The chat button appears in the bottom-right corner of the application.
  When clicked, it opens a chat modal that allows users to communicate with support staff.
  """
  def chat_button(assigns) do
    ~H"""
    <%= if not String.starts_with?(@current_path || "", "/dashboard") do %>
      <div class="chat-container">
        <button
          id="chat-toggle-button"
          phx-hook="ChatButton"
          class="chat-button fixed bottom-4 right-4 z-50 bg-primary hover:bg-primary/80 text-secondary rounded-full w-14 h-14 flex items-center justify-center shadow-lg transition-all"
        >
          <Lucideicons.message_circle class="h-6 w-6 chat-icon" />
          <Lucideicons.x class="h-6 w-6 close-icon hidden" />
        </button>

        <div
          id="chat-modal"
          class="chat-modal-wrapper fixed bottom-20 right-4 w-80 md:w-96 border border-gray-300 mb-2 bg-secondary rounded-lg shadow-xl hidden"
          phx-hook="ChatModal"
        >
          <div class="chat-modal-header flex justify-between items-center p-4 bg-primary text-white rounded-t-lg">
            <h3 class="text-lg font-semibold">Chat with Support</h3>
            <button id="close-chat-button" class="text-white hover:text-gray-200">
              <Lucideicons.x class="h-6 w-6" />
            </button>
          </div>
          <div class="chat-modal-body p-4">
            <div class="chat-modal-content" />
          </div>
        </div>
      </div>
    <% end %>
    """
  end
end
