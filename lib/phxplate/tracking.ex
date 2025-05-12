defmodule Phxplate.Tracking do
  @moduledoc """
  The Tracking context.
  """

  alias Phxplate.Tracking.Activity

  @doc """
  Tracks user activity.
  """
  def track_user_activity(action, user, actor, changes \\ %{}, metadata \\ %{}) do
    Activity.track(%{
      action: action,
      entity_type: "user",
      entity_id: user.id,
      changes: changes,
      metadata: metadata,
      actor_id: actor.id,
      company_id: nil
    })
  end

  @doc """
  Tracks company activity.
  """
  def track_company_activity(action, company, actor, changes \\ %{}, metadata \\ %{}) do
    Activity.track(%{
      action: action,
      entity_type: "company",
      entity_id: company.id,
      changes: changes,
      metadata: metadata,
      actor_id: actor.id,
      company_id: company.id
    })
  end

  @doc """
  Tracks employee activity.
  """
  def track_employee_activity(action, employee, actor, changes \\ %{}, metadata \\ %{}) do
    Activity.track(%{
      action: action,
      entity_type: "employee",
      entity_id: employee.id,
      changes: changes,
      metadata: metadata,
      actor_id: actor.id,
      company_id: employee.company_id
    })
  end

  @doc """
  Gets recent activities for a user.
  """
  def get_user_activities(user_id, limit \\ 10) do
    Activity.get_entity_activities("user", user_id, limit)
  end

  @doc """
  Gets recent activities for a company.
  """
  def get_company_activities(company_id, limit \\ 10) do
    Activity.get_company_activities(company_id, limit)
  end

  @doc """
  Gets recent activities for an employee.
  """
  def get_employee_activities(employee_id, limit \\ 10) do
    Activity.get_entity_activities("employee", employee_id, limit)
  end
end
