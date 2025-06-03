defmodule PhxplateWeb.Dashboard.SuperAdmin.FeedbackRequestsLive do
  @moduledoc """
  LiveView for feedback and feature requests management.

  This view provides functionality for viewing and managing feedback and feature requests
  submitted by users. It features a list of requests with filtering, pagination, and a tabbed
  detail view for viewing and deleting requests.
  """
  use PhxplateWeb, :live_view
  alias Phxplate.FeatureRequests
  alias PhxplateWeb.PageMeta
  alias Phoenix.LiveView.JS
  import PhxplateWeb.CoreComponents
  alias Phxplate.PubSub.DataSync
  import PhxplateWeb.Components.UI.Drawer

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      DataSync.subscribe("feature_requests", "all")
    end

    socket =
      socket
      |> assign(:selected_request, nil)
      |> assign(:delete_confirmation, false)
      |> assign(:show_drawer, false)
      |> assign(:request_type, :all)

    {:ok, load_requests(socket, 1)}
  end

  defp load_requests(socket, page) do
    per_page = 10
    request_type = socket.assigns[:request_type] || :all

    # Get requests with pagination and filtering
    requests =
      FeatureRequests.list_feature_requests(
        page: page,
        per_page: per_page,
        request_type: request_type
      )

    total_requests = FeatureRequests.count_feature_requests(request_type: request_type)
    total_pages = max(1, ceil(total_requests / per_page))

    socket
    |> assign(:requests, requests)
    |> assign(:page, page)
    |> assign(:total_pages, total_pages)
    |> assign(:per_page, per_page)
    |> assign(:total_requests, total_requests)
    |> PageMeta.assign_metadata(
      title: "Feature & Feedback Requests",
      description: "Manage feature and feedback requests",
      url: "/dashboard/feedback-requests"
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex-1 h-[calc(100vh-100px)]">
      <.header>
        Feature & Feedback Requests
        <:subtitle>View and manage user requests</:subtitle>
      </.header>

      <div class="grid grid-cols-1 lg:grid-cols-2 lg:gap-8 mt-4 h-[calc(100vh-200px)]">
        <div class="h-[calc(100vh-200px)] col-span-1">
          <div class="flex flex-col justify-start">
            <h2 class="text-xl font-semibold">Requests</h2>
            <div class="flex gap-2 mt-2">
              <.button
                phx-click="filter_requests"
                phx-value-type="all"
                variant={if @request_type == :all, do: "default", else: "outline"}
                size="sm"
              >
                All
              </.button>
              <.button
                phx-click="filter_requests"
                phx-value-type="feature"
                variant={if @request_type == :feature, do: "default", else: "outline"}
                size="sm"
              >
                Features
              </.button>
              <.button
                phx-click="filter_requests"
                phx-value-type="feedback"
                variant={if @request_type == :feedback, do: "default", else: "outline"}
                size="sm"
              >
                Feedback
              </.button>
            </div>
          </div>

          <%= if Enum.empty?(@requests) do %>
            <div class="p-4 bg-gray-50 rounded-md">
              <p class="text-gray-500 text-center">No requests available</p>
            </div>
          <% else %>
            <div class="divide-y">
              <%= for request <- @requests do %>
                <div
                  class="py-4 cursor-pointer hover:bg-gray-50 transition-colors"
                  phx-click="select_request"
                  phx-value-id={request.id}
                >
                  <div class="flex items-center justify-between">
                    <div class="flex flex-col space-y-1 ml-2 flex-1">
                      <div class="flex items-center justify-between">
                        <p class="font-medium truncate max-w-[200px]">
                          <%= PhxplateWeb.Components.Markdown.excerpt(request.feature_description, 30) %>
                        </p>
                        <div class="flex items-center gap-2 text-sm text-gray-500">
                          <span class={[
                            "px-2 py-0.5 rounded-full text-xs",
                            case request.feasibility_rating do
                              1 -> "bg-blue-100 text-blue-800"
                              2 -> "bg-purple-100 text-purple-800"
                              _ -> "bg-gray-100 text-gray-800"
                            end
                          ]}>
                            <%= if request.feasibility_rating == 1, do: "Feature", else: "Feedback" %>
                          </span>
                        </div>
                      </div>
                      <div class="flex justify-between items-center text-xs text-gray-500">
                        <span>Priority: <%= request.priority_rating %>/10</span>
                        <span><%= Calendar.strftime(request.inserted_at, "%Y-%m-%d at %H:%M:%S") %></span>
                      </div>
                    </div>
                    <Lucideicons.arrow_right class="w-5 h-5 mr-2 flex-shrink-0" />
                  </div>
                </div>
              <% end %>
            </div>
          <% end %>

          <%= if @total_pages > 1 do %>
            <div class="mt-6">
              <.pagination>
                <.pagination_content class="w-full flex justify-center items-center">
                  <%= if @page > 1 do %>
                    <.pagination_item>
                      <.pagination_link phx-click="paginate" phx-value-page={@page - 1}>
                        <Lucideicons.arrow_left class="w-3.5 h-3.5" />
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>

                  <%= for page_num <- max(1, @page - 2)..min(@total_pages, @page + 2) do %>
                    <.pagination_item>
                      <.pagination_link
                        phx-click="paginate"
                        phx-value-page={page_num}
                        is-active={page_num == @page}
                      >
                        {page_num}
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>

                  <%= if @page < @total_pages do %>
                    <.pagination_item>
                      <.pagination_link phx-click="paginate" phx-value-page={@page + 1}>
                        <Lucideicons.arrow_right class="w-3.5 h-3.5" />
                      </.pagination_link>
                    </.pagination_item>
                  <% end %>
                </.pagination_content>
              </.pagination>
            </div>
          <% end %>
        </div>

    <!-- Desktop Details View (hidden on mobile) -->
        <div class="hidden lg:block col-span-1 overflow-y-auto">
          <h2 class="text-xl font-semibold mb-4">Request Details</h2>
          <%= if @selected_request do %>
            {render_request_details(assign(assigns, :context, "desktop"))}
          <% else %>
            <p class="text-gray-500">Select a request to view details</p>
          <% end %>
        </div>
      </div>

    <!-- Mobile Drawer -->
      <div class="lg:hidden">
        <.drawer
          show={@show_drawer and @selected_request != nil}
          direction="bottom"
          on_cancel={JS.push("close_drawer")}
        >
          <.drawer_header>
            <h3 class="text-lg font-semibold">Request Details</h3>
          </.drawer_header>
          <.drawer_content>
            <%= if @selected_request do %>
              {render_request_details(assign(assigns, :context, "mobile"))}
            <% else %>
              <p class="text-gray-500">Select a request to view details</p>
            <% end %>
          </.drawer_content>
        </.drawer>
      </div>
    </div>
    """
  end

  # Extract the request details rendering into a separate function for reuse
  defp render_request_details(assigns) do
    # Add a context to make component IDs unique
    context = assigns[:context] || "desktop"
    assigns = assign(assigns, :context, context)

    ~H"""
    <.tabs :let={builder} default="view" id={"request-details-#{@context}"}>
      <.tabs_list class="grid w-full grid-cols-2">
        <.tabs_trigger builder={builder} value="view">View</.tabs_trigger>
        <.tabs_trigger builder={builder} value="delete">Delete</.tabs_trigger>
      </.tabs_list>

      <.tabs_content value="view">
        <div class="space-y-6 bg-white rounded-md shadow-sm p-6">
          <div>
            <div class="flex justify-between items-center mb-4">
              <h3 class="text-xl font-semibold">
                <%= if @selected_request.feasibility_rating == 1, do: "Feature Request", else: "Feedback" %>
              </h3>
              <span class={[
                "px-2 py-1 rounded-md text-sm font-medium",
                case @selected_request.feasibility_rating do
                  1 -> "bg-blue-100 text-blue-800"
                  2 -> "bg-purple-100 text-purple-800"
                  _ -> "bg-gray-100 text-gray-800"
                end
              ]}>
                Priority: {@selected_request.priority_rating}/10
              </span>
            </div>

            <div class="mb-6">
              <h4 class="text-sm font-medium text-gray-500 mb-1">Submitted</h4>
              <p class="text-sm">
                <%= Calendar.strftime(@selected_request.inserted_at, "%Y-%m-%d at %H:%M:%S") %>
              </p>
            </div>

            <div class="mb-6">
              <h4 class="text-sm font-medium text-gray-500 mb-1">User</h4>
              <p class="text-sm">
                <%= if @selected_request.user, do: @selected_request.user.email, else: "Anonymous" %>
              </p>
            </div>

            <div>
              <h4 class="text-sm font-medium text-gray-500 mb-2">Description</h4>
              <div class="p-4 bg-gray-50 rounded-md whitespace-pre-wrap text-sm">
                <%= @selected_request.feature_description %>
              </div>
            </div>
          </div>
        </div>
      </.tabs_content>

      <.tabs_content value="delete">
        <div class="p-6 bg-white rounded-md shadow-sm">
          <%= if @delete_confirmation do %>
            <div class="space-y-4">
              <div class="bg-red-50 border border-red-200 rounded-md p-4">
                <div class="flex items-start">
                  <div class="flex-shrink-0">
                    <Lucideicons.triangle_alert class="h-5 w-5 text-red-400" />
                  </div>
                  <div class="ml-3">
                    <h3 class="text-sm font-medium text-red-800">Confirm Deletion</h3>
                    <div class="mt-2 text-sm text-red-700">
                      <p>
                        Are you sure you want to delete this request? This action cannot be undone.
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <div class="flex justify-end space-x-3">
                <.button type="button" variant="outline" phx-click="cancel_delete">
                  Cancel
                </.button>
                <.button
                  type="button"
                  variant="destructive"
                  phx-click="delete_request"
                  phx-value-id={@selected_request.id}
                >
                  Delete
                </.button>
              </div>
            </div>
          <% else %>
            <div class="space-y-4">
              <p class="text-gray-700">To delete this request, click the button below.</p>
              <div class="flex justify-end">
                <.button type="button" variant="destructive" phx-click="confirm_delete">
                  Delete Request
                </.button>
              </div>
            </div>
          <% end %>
        </div>
      </.tabs_content>
    </.tabs>
    """
  end

  @impl true
  def handle_event("filter_requests", %{"type" => type}, socket) do
    request_type = String.to_existing_atom(type)
    socket = assign(socket, :request_type, request_type)
    {:noreply, load_requests(socket, 1)}
  end

  @impl true
  def handle_event("select_request", %{"id" => id}, socket) do
    # Get the feature request and preload the user association
    request = id |> FeatureRequests.get_feature_request!() |> Phxplate.Repo.preload(:user)

    socket =
      socket
      |> assign(:selected_request, request)
      |> assign(:delete_confirmation, false)
      |> assign(:show_drawer, true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_drawer", _, socket) do
    {:noreply, assign(socket, :show_drawer, false)}
  end

  @impl true
  def handle_event("paginate", %{"page" => page}, socket) do
    page = String.to_integer(page)
    {:noreply, load_requests(socket, page)}
  end

  @impl true
  def handle_event("confirm_delete", _, socket) do
    {:noreply, assign(socket, :delete_confirmation, true)}
  end

  @impl true
  def handle_event("cancel_delete", _, socket) do
    {:noreply, assign(socket, :delete_confirmation, false)}
  end

  @impl true
  def handle_event("delete_request", %{"id" => id}, socket) do
    request = FeatureRequests.get_feature_request!(id)
    {:ok, _} = FeatureRequests.delete_feature_request(request)

    socket =
      socket
      |> assign(:selected_request, nil)
      |> assign(:delete_confirmation, false)
      |> assign(:show_drawer, false)
      |> put_flash(:info, "Request deleted successfully")

    # No need to reload requests here as the PubSub event will trigger an update
    {:noreply, socket}
  end
  
  @impl true
  def handle_info({:created, feature_request}, socket) do
    # Reload the requests when a new feature request is created
    {:noreply, load_requests(socket, socket.assigns.page)}
  end

  @impl true
  def handle_info({:updated, feature_request}, socket) do
    # Reload the requests when a feature request is updated
    socket = load_requests(socket, socket.assigns.page)
    
    # If the updated request is currently selected, update it with the new data
    socket =
      if socket.assigns.selected_request && socket.assigns.selected_request.id == feature_request.id do
        updated_request = feature_request |> Phxplate.Repo.preload(:user)
        assign(socket, :selected_request, updated_request)
      else
        socket
      end
    
    {:noreply, socket}
  end

  @impl true
  def handle_info({:deleted, request_id}, socket) do
    # Reload the requests when a feature request is deleted
    socket = load_requests(socket, socket.assigns.page)
    
    # If the deleted request is currently selected, clear the selection
    socket =
      if socket.assigns.selected_request && socket.assigns.selected_request.id == request_id do
        assign(socket, :selected_request, nil)
      else
        socket
      end
    
    {:noreply, socket}
  end
end
