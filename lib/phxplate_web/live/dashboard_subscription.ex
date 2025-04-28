defmodule PhxplateWeb.DashboardSubscription do
  @moduledoc """
  Manages PubSub subscriptions for dashboard components.
  This module handles real-time updates for various dashboard sections.
  """

  use Phoenix.Component
  alias Phoenix.PubSub

  @doc """
  Subscribes to dashboard updates for a specific component.
  """
  def subscribe(component_name) do
    PubSub.subscribe(Phxplate.PubSub, "dashboard:#{component_name}")
  end

  @doc """
  Broadcasts updates to a specific dashboard component.
  """
  def broadcast(component_name, event, payload) do
    PubSub.broadcast(Phxplate.PubSub, "dashboard:#{component_name}", {event, payload})
  end

  @doc """
  Gets the current state of a dashboard component.
  """
  def get_state(component_name) do
    case :ets.lookup(:dashboard_state, component_name) do
      [{^component_name, state}] -> state
      [] -> nil
    end
  end

  @doc """
  Updates the state of a dashboard component.
  """
  def update_state(component_name, state) do
    :ets.insert(:dashboard_state, {component_name, state})
    broadcast(component_name, :state_updated, state)
  end

  @doc """
  Initializes the ETS table for dashboard state.
  """
  def init do
    try do
      :ets.new(:dashboard_state, [:named_table, :public, :set])
    rescue
      ArgumentError -> :ok
    end
  end
end
