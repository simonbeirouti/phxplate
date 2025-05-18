defmodule PhxplateWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use PhxplateWeb, :controller` and
  `use PhxplateWeb, :live_view`.
  """
  use PhxplateWeb, :html

  import PhxplateWeb.Components.DashboardLayout
  use SaladUI

  embed_templates "layouts/*"

  def auth(assigns) do
    current_path =
      case assigns do
        %{socket: %{private: %{connect_params: %{"_mounts" => 0}}}} ->
          assigns.socket.private.connect_params["request_path"]

        %{conn: conn} ->
          conn.request_path

        _ ->
          "/"
      end

    assigns = Map.put_new(assigns, :current_path, current_path)

    ~H"""
    <div class="flex flex-col lg:flex-row h-[calc(100vh-4.3rem)]">
      <div class="w-full lg:w-1/2 p-4">
        {@inner_content}
      </div>
      <div
        class="w-full lg:w-1/2 bg-cover bg-center"
        style="background-image: url('/images/coffee.jpg')"
      >
      </div>
    </div>
    """
  end

  def public(assigns) do
    ~H"""
    <div class="min-h-[calc(100vh-4rem)]">
      <main>
        {@inner_content}
      </main>
    </div>
    """
  end
end
