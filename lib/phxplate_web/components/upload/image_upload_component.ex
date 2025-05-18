defmodule PhxplateWeb.Components.Upload.ImageUploadComponent do
  @moduledoc """
  LiveComponent for handling image uploads with S3 integration.

  ## Props
  - `:type` - The type of image being uploaded (e.g., :avatar, :logo)
  - `:image_url` - Current image URL (optional)
  - `:on_upload_complete` - Event name to emit when upload completes
  - `:entity_type` - The entity type this image belongs to (e.g., :user, :company)
  - `:entity_id` - The ID of the entity

  ## Examples
      <.live_component
        module={ImageUploadComponent}
        id="profile-avatar"
        type={:avatar}
        image_url={@user.profile.avatar_url}
        entity_type={:user}
        entity_id={@user.id}
        on_upload_complete="image_uploaded"
      />
  """
  use PhxplateWeb, :live_component
  alias Phxplate.AWS.S3
  require Logger

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:uploaded_files, [])
     |> allow_upload(:image,
       accept: ~w(.jpg .jpeg .png .gif),
       max_entries: 1,
       max_file_size: 5_000_000,
       auto_upload: true,
       progress: &handle_progress/3
     )}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:on_upload_complete, fn -> "image_uploaded" end)
      |> assign_new(:entity_type, fn -> :generic end)
      |> assign_new(:entity_id, fn -> nil end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  @impl true
  def handle_event("save", _params, socket) do
    socket = handle_uploads(socket)
    {:noreply, socket}
  end

  # Handle file uploads
  defp handle_uploads(socket) do
    consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
      result = upload_to_s3(socket, path, entry)

      # Send the event to the parent LiveView
      send_upload_result_to_parent(socket, result)

      result
    end)

    socket
  end

  defp upload_to_s3(socket, path, entry) do
    # Use replace_file to delete the old image if there is one
    case S3.replace_file(
      %{path: path, filename: entry.client_name},
      socket.assigns.type,
      socket.assigns[:image_url],
      content_type: entry.client_type
    ) do
      {:ok, url} ->
        {:ok, url}

      {:error, reason} ->
        Logger.error("Failed to upload: #{inspect(reason)}")
        {:error, "Failed to upload: #{inspect(reason)}"}
    end
  end

  defp send_upload_result_to_parent(socket, {:ok, url}) do
    send(self(), {
      String.to_atom(socket.assigns.on_upload_complete),
      %{
        type: socket.assigns.type,
        url: url,
        old_url: socket.assigns[:image_url],
        entity_type: socket.assigns.entity_type,
        entity_id: socket.assigns.entity_id
      }
    })
  end

  defp send_upload_result_to_parent(socket, {:error, error_msg}) do
    send(self(), {
      String.to_atom("#{socket.assigns.on_upload_complete}_error"),
      %{
        type: socket.assigns.type,
        error: error_msg,
        entity_type: socket.assigns.entity_type,
        entity_id: socket.assigns.entity_id
      }
    })
  end

  # Handle upload progress with logging
  defp handle_progress(:image, entry, socket) do
    if entry.done? do
      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted (allowed: jpg, jpeg, png, gif)"
  defp error_to_string(:too_many_files), do: "Too many files (max 1)"
  defp error_to_string(err), do: "Error: #{inspect(err)}"

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <form phx-submit="save" phx-change="validate" phx-target={@myself}>
        <div class="flex items-center gap-4">
          <div class="relative w-32 h-32" phx-drop-target={@uploads.image.ref}>
            <div class="w-full h-full overflow-hidden border-2 border-gray-200 rounded-full">
              <%= if Enum.any?(@uploads.image.entries) do %>
                <.live_img_preview entry={hd(@uploads.image.entries)} class="w-full h-full object-cover" />
              <% else %>
                <img
                  src={@image_url || "/images/default-avatar.png"}
                  alt="Image"
                  class="w-full h-full object-cover"
                />
              <% end %>
              <div class="absolute inset-0 flex items-center justify-center bg-black bg-opacity-50 opacity-0 hover:opacity-100 transition-opacity cursor-pointer rounded-full">
                <div class="relative w-full h-full flex items-center justify-center">
                  <Lucideicons.camera class="w-8 h-8 text-white pointer-events-none" />
                  <.live_file_input
                    upload={@uploads.image}
                    class="absolute inset-0 opacity-0 cursor-pointer w-full h-full"
                  />
                </div>
              </div>
            </div>

            <%= for err <- upload_errors(@uploads.image) do %>
              <p class="absolute -bottom-6 left-0 right-0 text-center text-sm text-red-500">
                <%= error_to_string(err) %>
              </p>
            <% end %>
          </div>

          <%= if Enum.any?(@uploads.image.entries) do %>
            <div class="flex flex-col gap-2">
              <%= for entry <- @uploads.image.entries do %>
                <div class="flex flex-col gap-2">
                  <.button
                    type="button"
                    variant="destructive"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    phx-target={@myself}
                    class="flex items-center gap-1"
                  >
                    <Lucideicons.x class="w-4 h-4" /> Cancel
                  </.button>

                  <.button
                    type="submit"
                    class="flex items-center gap-1"
                    phx-disable-with="Uploading..."
                  >
                    <Lucideicons.upload class="w-4 h-4" /> Confirm
                  </.button>

                  <%= for err <- upload_errors(@uploads.image, entry) do %>
                    <p class="text-red-500 text-xs"><%= error_to_string(err) %></p>
                  <% end %>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>
      </form>
    </div>
    """
  end
end
