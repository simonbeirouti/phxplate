defmodule PhxplateWeb.Components.AI.EvaluationQueue do
  @moduledoc """
  Component for displaying the evaluation queue status in an accordion format.
  """
  use PhxplateWeb.Component
  import PhxplateWeb.Components.UI.Accordion

  attr :queue_status, :map, required: true
  attr :class, :string, default: nil

  def evaluation_queue_accordion(assigns) do
    ~H"""
    <div class={classes(["mt-4 mb-6", @class])}>
      <div class="bg-white shadow rounded-lg">
        <.accordion>
          <.accordion_item>
            <.accordion_trigger group="queue">
              <div class="flex items-center justify-start ml-4 w-full">
                <h3 class="text-lg font-medium text-gray-900">Evaluation Queue</h3>
              </div>
            </.accordion_trigger>
            <.accordion_content>
              <div class="grid grid-cols-2 gap-4 mx-4">
                <div class="bg-blue-50 overflow-hidden shadow rounded-lg">
                  <div class="p-4">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <div class="w-8 h-8 bg-blue-500 rounded-md flex items-center justify-center">
                          <span class="text-white font-bold text-sm"><%= @queue_status.queue_size %></span>
                        </div>
                      </div>
                      <div class="ml-3 w-0 flex-1">
                        <dl>
                          <dt class="text-xs font-medium text-gray-500 truncate">
                            Pending Evaluations
                          </dt>
                          <dd class="text-sm font-medium text-gray-900">
                            <%= @queue_status.queue_size %> in queue
                          </dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>

                <div class="bg-green-50 overflow-hidden shadow rounded-lg">
                  <div class="p-4">
                    <div class="flex items-center">
                      <div class="flex-shrink-0">
                        <div class="w-8 h-8 bg-green-500 rounded-md flex items-center justify-center">
                          <%= if @queue_status.current_evaluation do %>
                            <span class="text-white text-xs">⚡</span>
                          <% else %>
                            <span class="text-white text-xs">💤</span>
                          <% end %>
                        </div>
                      </div>
                      <div class="ml-3 w-0 flex-1">
                        <dl>
                          <dt class="text-xs font-medium text-gray-500 truncate">
                            Current Status
                          </dt>
                          <dd class="text-sm font-medium text-gray-900">
                            <%= if @queue_status.current_evaluation do %>
                              Running #<%= @queue_status.current_evaluation.eval_run_id %>
                            <% else %>
                              Idle
                            <% end %>
                          </dd>
                        </dl>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </.accordion_content>
          </.accordion_item>
        </.accordion>
      </div>
    </div>
    """
  end
end
