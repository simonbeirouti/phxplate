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
  import PhxplateWeb.Components.AI.{ModelSelector, PromptSelector}
  import PhxplateWeb.Components.UI.{Slider, Switch}

  @impl true
  def mount(_params, _session, socket) do
    user_id = socket.assigns.current_user.id
    conversations = AI.list_conversations(user_id)
    all_prompts = AI.list_prompts_for_chat()
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
     |> assign(:selected_system_prompt, get_default_system_prompt_name(all_prompts))
     |> assign(:current_system_prompt, default_system_prompt)
     |> assign(:screen_mode, "dialog")
     |> assign(:page_title, "AI Chat")
     |> assign(:show_advanced_settings, false)
     |> assign(:max_tokens, 4000)
     |> assign(:max_tokens_active, false)
     |> assign(:temperature, 0.7)
     |> assign(:temperature_active, false)
     |> assign(:top_k, 5)
     |> assign(:top_k_active, false)
     |> assign(:top_p, 0.9)
     |> assign(:top_p_active, false)
     |> assign(:is_new_conversation, false)
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

            # Load advanced parameters from conversation
            socket = load_advanced_params_from_conversation(socket, conversation)

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

    # Include current advanced parameters if any are active
    advanced_params = build_advanced_params_for_conversation(socket.assigns)

    case AI.create_conversation(
           user_id,
           title,
           socket.assigns.current_system_prompt,
           advanced_params
         ) do
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

    socket =
      socket
      |> assign(:selected_system_prompt, selected_prompt)
      |> assign(:current_system_prompt, current_system_prompt)

    # Save prompt selection to current conversation if one exists
    if socket.assigns.current_conversation do
      user_id = socket.assigns.current_user.id
      conversation_id = socket.assigns.current_conversation.id
      prompt_id = get_prompt_id_from_name(selected_prompt, socket.assigns.available_prompts)

      Task.start(fn ->
        AI.update_conversation_prompt(conversation_id, user_id, %{selected_prompt_id: prompt_id})
      end)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set_screen_mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :screen_mode, mode)}
  end

  @impl true
  def handle_event("show_advanced_settings", _params, socket) do
    {:noreply, assign(socket, :show_advanced_settings, true)}
  end

  @impl true
  def handle_event("close_advanced_settings", _params, socket) do
    {:noreply, assign(socket, :show_advanced_settings, false)}
  end

  @impl true
  def handle_event("update_advanced_settings", params, socket) do
    # Debug: Log the incoming parameters
    IO.puts("🔧 Advanced settings update received:")
    IO.inspect(params, label: "Params")

    # Convert slider integer values back to appropriate ranges
    temperature =
      case params["temperature"] do
        nil -> 0.7
        temp_str -> String.to_integer(temp_str) / 100.0
      end

    top_p =
      case params["top_p"] do
        nil -> 0.9
        top_p_str -> String.to_integer(top_p_str) / 100.0
      end

    # Parse the new values
    max_tokens = String.to_integer(params["max_tokens"] || "4000")
    max_tokens_active = params["max_tokens_active"] == "true"
    temperature_active = params["temperature_active"] == "true"
    top_k = String.to_integer(params["top_k"] || "5")
    top_k_active = params["top_k_active"] == "true"
    top_p_active = params["top_p_active"] == "true"

    socket =
      socket
      |> assign(:max_tokens, max_tokens)
      |> assign(:max_tokens_active, max_tokens_active)
      |> assign(:temperature, temperature)
      |> assign(:temperature_active, temperature_active)
      |> assign(:top_k, top_k)
      |> assign(:top_k_active, top_k_active)
      |> assign(:top_p, top_p)
      |> assign(:top_p_active, top_p_active)

    # Save advanced parameters to current conversation if one exists
    if socket.assigns.current_conversation do
      user_id = socket.assigns.current_user.id
      conversation_id = socket.assigns.current_conversation.id

      # Build advanced params from the new values
      advanced_params = %{
        max_tokens: if(max_tokens_active, do: max_tokens, else: nil),
        max_tokens_active: max_tokens_active,
        temperature: if(temperature_active, do: temperature, else: nil),
        temperature_active: temperature_active,
        top_k: if(top_k_active, do: top_k, else: nil),
        top_k_active: top_k_active,
        top_p: if(top_p_active, do: top_p, else: nil),
        top_p_active: top_p_active
      }

      Task.start(fn ->
        case AI.update_conversation_advanced_params(conversation_id, user_id, advanced_params) do
          {:ok, _conversation} ->
            :ok
          {:error, reason} ->
            {:error, reason}
        end
      end)
    else
      :ok
    end

    {:noreply, socket}
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
    trimmed_message = String.trim(message)

    case socket.assigns.current_conversation do
      nil ->
        # Create new conversation and immediately send message
        user_id = socket.assigns.current_user.id
        title = "New Conversation"

        # Include current advanced parameters if any are active
        advanced_params = build_advanced_params_for_conversation(socket.assigns)

        case AI.create_conversation(
               user_id,
               title,
               socket.assigns.current_system_prompt,
               advanced_params
             ) do
                    {:ok, conversation} ->
            conversations = AI.list_conversations(user_id)

            # Set loading state and clear input (don't add user message yet - let AI module handle it)
            socket =
              socket
              |> assign(:conversations, conversations)
              |> assign(:current_conversation, conversation)
              |> assign(:messages, [])
              |> assign(:input_message, "")
              |> assign(:loading, true)
              |> assign(:streaming, true)
              |> assign(:current_stream, "")
              |> assign(:show_mobile_drawer, false)
              |> assign(:is_new_conversation, true)  # Flag to track new conversation

            # Send async request to AI
            pid = self()
            conversation_id = conversation.id

                        Task.start(fn ->
              IO.puts("🚀 Starting AI chat task for new conversation #{conversation_id}")

              selected_model_api_id = get_model_api_id(socket.assigns.selected_model)
              IO.puts("📱 Selected model: #{selected_model_api_id}")

              # Build advanced parameters
              advanced_opts = %{
                max_tokens: socket.assigns.max_tokens,
                max_tokens_active: socket.assigns.max_tokens_active,
                temperature: socket.assigns.temperature,
                temperature_active: socket.assigns.temperature_active,
                top_k: socket.assigns.top_k,
                top_k_active: socket.assigns.top_k_active,
                top_p: socket.assigns.top_p,
                top_p_active: socket.assigns.top_p_active,
                prompt_id: get_prompt_id_from_name(socket.assigns.selected_system_prompt, socket.assigns.available_prompts)
              }

              IO.puts("⚙️ Advanced opts: #{inspect(advanced_opts)}")
              IO.puts("💬 Message: #{trimmed_message}")

              case AI.stream_chat_in_conversation(
                     conversation_id,
                     user_id,
                     trimmed_message,
                     selected_model_api_id,
                     advanced_opts
                   ) do
                {:ok, stream, _conversation, model_api_id, opts} ->
                  IO.puts("✅ AI streaming started successfully")
                  # First, send the user message to display
                  send(pid, {:user_message_added, trimmed_message})

                  accumulated_response =
                    stream
                    |> Stream.map(&AI.extract_text_from_stream/1)
                    |> Enum.reduce("", fn chunk, acc ->
                      new_acc = acc <> chunk
                      send(pid, {:stream_chunk, chunk})
                      new_acc
                    end)

                  IO.puts("🏁 AI streaming completed")
                  send(
                    pid,
                    {:stream_complete, accumulated_response, conversation_id, model_api_id, opts}
                  )

                {:error, error} ->
                  IO.puts("❌ AI streaming error: #{inspect(error)}")
                  send(pid, {:ai_error, error})
              end
            end)

            {:noreply, socket}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "Failed to create new conversation")}
        end

      conversation ->
        # Add user message to the chat display immediately
        user_message = %{
          role: "user",
          content: trimmed_message,
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

          # Build advanced parameters
          advanced_opts = %{
            max_tokens: socket.assigns.max_tokens,
            max_tokens_active: socket.assigns.max_tokens_active,
            temperature: socket.assigns.temperature,
            temperature_active: socket.assigns.temperature_active,
            top_k: socket.assigns.top_k,
            top_k_active: socket.assigns.top_k_active,
            top_p: socket.assigns.top_p,
            top_p_active: socket.assigns.top_p_active,
            prompt_id: get_prompt_id_from_name(socket.assigns.selected_system_prompt, socket.assigns.available_prompts)
          }

          case AI.stream_chat_in_conversation(
                 conversation.id,
                 user_id,
                 trimmed_message,
                 selected_model_api_id,
                 advanced_opts
               ) do
            {:ok, stream, _conversation, model_api_id, opts} ->
              accumulated_response =
                stream
                |> Stream.map(&AI.extract_text_from_stream/1)
                |> Enum.reduce("", fn chunk, acc ->
                  new_acc = acc <> chunk
                  send(pid, {:stream_chunk, chunk})
                  new_acc
                end)

              send(
                pid,
                {:stream_complete, accumulated_response, conversation.id, model_api_id, opts}
              )

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
  def handle_info({:user_message_added, message}, socket) do
    # Add the user message to the display
    user_message = %{
      role: "user",
      content: message,
      timestamp: DateTime.utc_now()
    }

    messages = socket.assigns.messages ++ [user_message]
    {:noreply, assign(socket, :messages, messages)}
  end

  @impl true
  def handle_info({:stream_chunk, chunk}, socket) do
    current_stream = socket.assigns.current_stream <> chunk
    {:noreply, assign(socket, :current_stream, current_stream)}
  end

  @impl true
  def handle_info({:stream_complete, full_response, conversation_id, model_api_id, opts}, socket) do
    # Save the complete AI response to the database
    Task.start(fn ->
      AI.complete_streaming_conversation(conversation_id, full_response, model_api_id, opts)
    end)

    # Check if this is the first AI response in the conversation (for auto-naming)
    # Only user message exists
    is_first_response = length(socket.assigns.messages) == 1

    # Add the complete streamed message to the chat display
    # Include metadata for advanced parameters if any were active
    metadata = if opts[:max_tokens_active] || opts[:temperature_active] || opts[:top_k_active] || opts[:top_p_active] do
      %{
        max_tokens: if(opts[:max_tokens_active], do: opts[:max_tokens], else: nil),
        temperature: if(opts[:temperature_active], do: opts[:temperature], else: nil),
        top_k: if(opts[:top_k_active], do: opts[:top_k], else: nil),
        top_p: if(opts[:top_p_active], do: opts[:top_p], else: nil)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()
    else
      %{}
    end

    ai_message = %{
      role: "assistant",
      content: full_response,
      model: get_model_short_name(model_api_id),
      timestamp: DateTime.utc_now(),
      metadata: metadata
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

    # Navigate to the conversation URL if this was a new conversation
    socket = if Map.get(socket.assigns, :is_new_conversation, false) do
      socket
      |> assign(:is_new_conversation, false)
      |> push_navigate(to: ~p"/dashboard/super_admin/ai-chat/#{conversation_id}")
    else
      socket
    end

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:conversations, conversations)
     |> assign(:loading, false)
     |> assign(:streaming, false)
     |> assign(:current_stream, "")}
  end

  # Backward compatibility handler for old format without opts
  @impl true
  def handle_info({:stream_complete, full_response, conversation_id, model_api_id}, socket) do
    handle_info({:stream_complete, full_response, conversation_id, model_api_id, %{}}, socket)
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

  # Helper function to get prompt ID from name
  defp get_prompt_id_from_name("Default System", _prompts), do: nil
  defp get_prompt_id_from_name(prompt_name, prompts) do
    case Enum.find(prompts, &(&1.name == prompt_name)) do
      nil -> nil
      prompt -> prompt.id
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
        timestamp: msg.inserted_at,
        metadata: msg.metadata || %{}
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

    # Helper function to check if a message has active advanced parameters
  defp has_active_advanced_params?(message) do
    # Check if any advanced parameter fields are populated (these are only set when active)
    # For messages loaded from database, these will be in the message struct
    # For display messages, we need to check metadata
    case message do
      %{max_tokens: max_tokens, temperature: temp, top_k: top_k, top_p: top_p}
      when not is_nil(max_tokens) or not is_nil(temp) or not is_nil(top_k) or not is_nil(top_p) ->
        true

      _ ->
        # Fallback to metadata check for display messages
        metadata = Map.get(message, :metadata, %{})
        # Only show as advanced if parameters differ from defaults
        (metadata[:max_tokens] && metadata[:max_tokens] != 4000) ||
        (metadata[:temperature] && metadata[:temperature] != 0.7) ||
        (metadata[:top_k] && metadata[:top_k] != 5) ||
        (metadata[:top_p] && metadata[:top_p] != 0.9)
    end
  end

  # Helper function to build advanced parameters for conversation storage
  defp build_advanced_params_for_conversation(assigns) do
    %{
      max_tokens: if(assigns.max_tokens_active, do: assigns.max_tokens, else: nil),
      max_tokens_active: assigns.max_tokens_active,
      temperature: if(assigns.temperature_active, do: assigns.temperature, else: nil),
      temperature_active: assigns.temperature_active,
      top_k: if(assigns.top_k_active, do: assigns.top_k, else: nil),
      top_k_active: assigns.top_k_active,
      top_p: if(assigns.top_p_active, do: assigns.top_p, else: nil),
      top_p_active: assigns.top_p_active,
      selected_prompt_id: get_prompt_id_from_name(assigns.selected_system_prompt, assigns.available_prompts)
    }
  end

  # Helper function to load advanced parameters from conversation
  defp load_advanced_params_from_conversation(socket, conversation) do
    # Load prompt selection from conversation or fallback to defaults
    selected_system_prompt =
      if conversation.selected_prompt_id do
        case Enum.find(socket.assigns.available_prompts, &(&1.id == conversation.selected_prompt_id)) do
          nil -> get_default_system_prompt_name(socket.assigns.available_prompts)
          prompt -> prompt.name
        end
      else
        get_default_system_prompt_name(socket.assigns.available_prompts)
      end

    # Update current system prompt content
    current_system_prompt =
      case selected_system_prompt do
        "Default System" -> AI.get_default_system_prompt()
        name ->
          case Enum.find(socket.assigns.available_prompts, &(&1.name == name)) do
            nil -> AI.get_default_system_prompt()
            prompt -> prompt.content
          end
      end

    socket
    |> assign(:max_tokens, conversation.max_tokens || 4000)
    |> assign(:max_tokens_active, conversation.max_tokens_active || false)
    |> assign(:temperature, conversation.temperature || 0.7)
    |> assign(:temperature_active, conversation.temperature_active || false)
    |> assign(:top_k, conversation.top_k || 5)
    |> assign(:top_k_active, conversation.top_k_active || false)
    |> assign(:top_p, conversation.top_p || 0.9)
    |> assign(:top_p_active, conversation.top_p_active || false)
    |> assign(:selected_system_prompt, selected_system_prompt)
    |> assign(:current_system_prompt, current_system_prompt)
  end

  # Component for advanced AI settings
  defp advanced_settings_content(assigns) do
    ~H"""
    <div class="space-y-6">
      <.form
        for={%{}}
        as={:advanced_settings}
        phx-change="update_advanced_settings"
        class="grid grid-cols-2 gap-6"
      >
        <!-- Max Tokens -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-sm font-medium text-gray-900">Max Tokens</label>
            <div class="flex items-center gap-2">
              <span class={[
                "text-xs px-2 py-1 rounded-full",
                if(@max_tokens_active,
                  do: "bg-green-100 text-green-800",
                  else: "bg-gray-100 text-gray-600"
                )
              ]}>
                {if @max_tokens_active, do: "Active", else: "Inactive"}
              </span>
              <.switch
                id="max_tokens_active_switch"
                name="max_tokens_active"
                value={@max_tokens_active}
              />
            </div>
          </div>
          <div class="space-y-2">
            <.slider
              id="max_tokens_slider"
              name="max_tokens"
              value={@max_tokens}
              min={1}
              max={4096}
              step={1}
              class={[
                "w-full",
                if(!@max_tokens_active, do: "opacity-50 pointer-events-none", else: "")
              ]}
            />
            <div class="flex justify-between text-xs text-gray-500">
              <span>1</span>
              <span class="font-medium">{@max_tokens}</span>
              <span>4096</span>
            </div>
          </div>
          <p class="text-xs text-gray-500">
            Maximum number of tokens to generate in the response.
          </p>
        </div>

    <!-- Temperature -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-sm font-medium text-gray-900">Temperature</label>
            <div class="flex items-center gap-2">
              <span class={[
                "text-xs px-2 py-1 rounded-full",
                if(@temperature_active,
                  do: "bg-green-100 text-green-800",
                  else: "bg-gray-100 text-gray-600"
                )
              ]}>
                {if @temperature_active, do: "Active", else: "Inactive"}
              </span>
              <.switch
                id="temperature_active_switch"
                name="temperature_active"
                value={@temperature_active}
              />
            </div>
          </div>
          <div class="space-y-2">
            <.slider
              id="temperature_slider"
              name="temperature"
              value={round(@temperature * 100)}
              min={0}
              max={100}
              step={1}
              class={[
                "w-full",
                if(!@temperature_active, do: "opacity-50 pointer-events-none", else: "")
              ]}
            />
            <div class="flex justify-between text-xs text-gray-500">
              <span>0.00</span>
              <span class="font-medium">{Float.round(@temperature, 2)}</span>
              <span>1.00</span>
            </div>
          </div>
          <p class="text-xs text-gray-500">
            Controls randomness. Lower values make responses more focused and deterministic.
          </p>
        </div>

    <!-- Top K -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-sm font-medium text-gray-900">Top K</label>
            <div class="flex items-center gap-2">
              <span class={[
                "text-xs px-2 py-1 rounded-full",
                if(@top_k_active,
                  do: "bg-green-100 text-green-800",
                  else: "bg-gray-100 text-gray-600"
                )
              ]}>
                {if @top_k_active, do: "Active", else: "Inactive"}
              </span>
              <.switch id="top_k_active_switch" name="top_k_active" value={@top_k_active} />
            </div>
          </div>
          <div class="space-y-2">
            <.slider
              id="top_k_slider"
              name="top_k"
              value={@top_k}
              min={1}
              max={5}
              step={1}
              class={["w-full", if(!@top_k_active, do: "opacity-50 pointer-events-none", else: "")]}
            />
            <div class="flex justify-between text-xs text-gray-500">
              <span>1</span>
              <span class="font-medium">{@top_k}</span>
              <span>5</span>
            </div>
          </div>
          <p class="text-xs text-gray-500">
            Limits the number of highest probability tokens to consider.
          </p>
        </div>

    <!-- Top P -->
        <div class="space-y-3">
          <div class="flex items-center justify-between">
            <label class="text-sm font-medium text-gray-900">Top P</label>
            <div class="flex items-center gap-2">
              <span class={[
                "text-xs px-2 py-1 rounded-full",
                if(@top_p_active,
                  do: "bg-green-100 text-green-800",
                  else: "bg-gray-100 text-gray-600"
                )
              ]}>
                {if @top_p_active, do: "Active", else: "Inactive"}
              </span>
              <.switch id="top_p_active_switch" name="top_p_active" value={@top_p_active} />
            </div>
          </div>
          <div class="space-y-2">
            <.slider
              id="top_p_slider"
              name="top_p"
              value={round(@top_p * 100)}
              min={1}
              max={100}
              step={1}
              class={["w-full", if(!@top_p_active, do: "opacity-50 pointer-events-none", else: "")]}
            />
            <div class="flex justify-between text-xs text-gray-500">
              <span>0.01</span>
              <span class="font-medium">{Float.round(@top_p, 2)}</span>
              <span>1.00</span>
            </div>
          </div>
          <p class="text-xs text-gray-500">
            Cumulative probability cutoff for token selection.
          </p>
        </div>
      </.form>

      <div class="col-span-2 flex justify-end pt-4 border-t border-gray-200">
        <.button variant="outline" phx-click="close_advanced_settings" class="w-full">
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
            <.button phx-click="new_conversation" class="bg-black hover:bg-gray-800">
              <Lucideicons.plus class="h-4 w-4 mr-2" /> New Chat
            </.button>
          </:actions>
        </.header>

        <div class="mt-4 mb-4 w-full">
          <div class="flex items-center gap-2 h-10">
            <.model_selector
              selected_model={@selected_model}
              on_change="select_model"
              class="w-[140px]"
            />
            <.prompt_selector
              available_prompts={@available_prompts}
              selected_prompt={@selected_system_prompt}
              on_change="select_system_prompt"
              class="w-48"
              id="system-prompt-select"
            />
            <.button
              variant="outline"
              phx-click="show_advanced_settings"
              title="Advanced AI Parameters"
            >
              <Lucideicons.settings class="h-4 w-4" />
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
                <%= if @max_tokens_active || @temperature_active || @top_k_active || @top_p_active do %>
                  <p class="text-xs text-blue-600 mt-1">
                    <Lucideicons.settings class="h-3 w-3 inline mr-1" /> Advanced parameters: Active
                  </p>
                <% end %>
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
                          <%= if has_active_advanced_params?(message) do %>
                            <span
                              class="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full"
                              title="Advanced parameters used"
                            >
                              <Lucideicons.settings class="h-3 w-3 inline mr-1" /> Advanced
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
                    <%= if @max_tokens_active || @temperature_active || @top_k_active || @top_p_active do %>
                      <span
                        class="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded-full"
                        title="Advanced parameters active"
                      >
                        <Lucideicons.settings class="h-3 w-3 inline mr-1" /> Advanced
                      </span>
                    <% end %>
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
      id="advanced-settings-wrapper"
      show={@show_advanced_settings}
      hook="DialogDrawerMode"
      mode={@screen_mode}
      on_cancel={JS.push("close_advanced_settings")}
      name="Advanced AI Parameters"
      description="Configure advanced parameters for AI responses"
      class="sm:max-w-6xl"
    >
      <.advanced_settings_content
        max_tokens={@max_tokens}
        max_tokens_active={@max_tokens_active}
        temperature={@temperature}
        temperature_active={@temperature_active}
        top_k={@top_k}
        top_k_active={@top_k_active}
        top_p={@top_p}
        top_p_active={@top_p_active}
      />
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
