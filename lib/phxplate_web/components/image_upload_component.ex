defmodule PhxplateWeb.Components.ImageUploadComponent do
  use PhxplateWeb, :live_component

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("upload_image", %{"file" => file_data}, socket) do
    # Here we would handle the actual file upload
    # For now, we'll just simulate it by updating the URL
    # TODO: Implement actual file upload logic

    case process_upload(file_data, socket.assigns.type) do
      {:ok, url} ->
        send(self(), {:image_uploaded, %{type: socket.assigns.type, url: url}})
        {:noreply, assign(socket, :loading, false)}

      {:error, reason} ->
        send(self(), {:flash_msg, :error, "Failed to upload image: #{reason}"})
        {:noreply, assign(socket, :loading, false)}
    end
  end

  defp process_upload(file_data, type) do
    # TODO: Implement actual file upload logic
    # This is a placeholder that simulates success/failure
    if is_map(file_data) do
      {:ok, "/images/#{type}/#{:rand.uniform(1000)}.jpg"}
    else
      {:error, "Invalid file data"}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class={[
      "relative",
      @type == :avatar && "w-32 h-32",
      @type == :logo && "w-32 h-32"
    ]}>
      <div class={[
        "w-full h-full overflow-hidden border-2 border-gray-200",
        @type == :avatar && "rounded-full",
        @type == :logo && "rounded-lg"
      ]}>
        <img
          src={@image_url || "/images/default-#{@type}.png"}
          alt={if @type == :avatar, do: "Profile avatar", else: "Company logo"}
          class="w-full h-full object-cover"
        />
        <div class={[
          "absolute inset-0 flex items-center justify-center bg-black bg-opacity-50 opacity-0 hover:opacity-100 transition-opacity cursor-pointer",
          @type == :avatar && "rounded-full",
          @type == :logo && "rounded-lg"
        ]}>
          <div class="relative">
            <Lucideicons.camera class="w-8 h-8 text-white absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none" />
            <input
              type="file"
              name="file"
              accept="image/*"
              class="absolute inset-0 opacity-0 cursor-pointer"
              phx-change="upload_image"
              phx-target={@myself}
            />
          </div>
        </div>
      </div>
    </div>
    """
  end
end
