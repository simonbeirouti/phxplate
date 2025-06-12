defmodule PhxplateWeb.SupportStatusChannel do
  use PhxplateWeb, :channel

  @impl true
  def join("support:status", _payload, socket) do
    # Anyone can join this channel to receive status updates
    {:ok, %{status: get_current_status()}, socket}
  end

  @impl true
  def handle_in("update_status", %{"status" => status}, socket) do
    if authorized?(socket) do
      # Broadcast the status update to all subscribers on this channel
      broadcast(socket, "status_changed", %{status: status})
      {:reply, {:ok, %{status: status}}, socket}
    else
      {:reply, {:error, %{reason: "unauthorized"}}, socket}
    end
  end

  # Helper functions

  defp authorized?(socket) do
    case socket.assigns[:current_user] do
      %{role: role} when role in [:admin, :super_admin] -> true
      _ -> false
    end
  end

  defp get_current_status() do
    # Get status from the Agent
    Phxplate.SupportStatus.get_status()
  end
end
