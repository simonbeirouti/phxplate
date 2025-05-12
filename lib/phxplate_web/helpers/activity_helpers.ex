defmodule PhxplateWeb.Helpers.ActivityHelpers do
  @moduledoc """
  Helper functions for handling activity-related data formatting and display.
  """

  @doc """
  Humanizes an action string by replacing underscores with spaces and capitalizing.
  """
  def humanize_action("role_update"), do: "Role Updated"
  def humanize_action("subscription_status_update"), do: "Subscription Status Updated"
  def humanize_action("subscription_tier_update"), do: "Subscription Tier Updated"
  def humanize_action("company_create"), do: "Company Created"
  def humanize_action("company_update"), do: "Company Updated"
  def humanize_action("employee_delete"), do: "Employee Deleted"
  def humanize_action(action) when is_binary(action) do
    action
    |> String.replace("_", " ")
    |> String.capitalize()
  end
  def humanize_action(action), do: Phoenix.Naming.humanize(action)

  @doc """
  Humanizes a key by replacing underscores with spaces and capitalizing.
  """
  def humanize_key(key) when is_binary(key) do
    key
    |> String.replace("_", " ")
    |> String.capitalize()
  end
  def humanize_key(key), do: Phoenix.Naming.humanize(key)
end
