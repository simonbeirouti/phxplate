defmodule Phxplate.Tracking do
  @moduledoc """
  The Tracking context.

  This context provides functions for tracking and auditing user activities
  across the application. It enables recording various actions performed by users,
  such as creating or updating resources, with detailed tracking of changes made.
  The tracking system helps maintain an audit trail for compliance and debugging
  purposes, and allows retrieving historical activity for users, companies, and employees.
  """

  alias Phxplate.Tracking.Activity

  @doc """
  Tracks user activity.

  Records an action performed by a user on a user entity (their own account or another user's).
  Stores information about what was changed and any additional metadata.

  ## Parameters
    - action: The type of action performed (e.g., "profile_update", "role_update")
    - user: The user entity that was affected by the action
    - actor: The user who performed the action
    - changes: Map of changes made during the action (default: empty map)
    - metadata: Additional contextual information (default: empty map)

  ## Returns
    - `{:ok, activity}` on successful recording
    - `{:error, changeset}` on validation failure
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

  Records an action performed by a user on a company entity.
  Stores information about what was changed and any additional metadata.

  ## Parameters
    - action: The type of action performed (e.g., "company_create", "company_update")
    - company: The company entity that was affected by the action
    - actor: The user who performed the action
    - changes: Map of changes made during the action (default: empty map)
    - metadata: Additional contextual information (default: empty map)

  ## Returns
    - `{:ok, activity}` on successful recording
    - `{:error, changeset}` on validation failure
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

  Records an action performed by a user on an employee entity.
  Stores information about what was changed and any additional metadata.

  ## Parameters
    - action: The type of action performed (e.g., "employee_create", "employee_update")
    - employee: The employee entity that was affected by the action
    - actor: The user who performed the action
    - changes: Map of changes made during the action (default: empty map)
    - metadata: Additional contextual information (default: empty map)

  ## Returns
    - `{:ok, activity}` on successful recording
    - `{:error, changeset}` on validation failure
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

  Retrieves the most recent activities related to a specific user,
  ordered by date with newest first.

  ## Parameters
    - user_id: The ID of the user
    - limit: Maximum number of activities to retrieve (default: 10)

  ## Returns
    - List of activity records with associated actors
  """
  def get_user_activities(user_id, limit \\ 10) do
    Activity.get_entity_activities("user", user_id, limit)
  end

  @doc """
  Gets recent activities for a company.

  Retrieves the most recent activities performed in the context of a specific company,
  ordered by date with newest first.

  ## Parameters
    - company_id: The ID of the company
    - limit: Maximum number of activities to retrieve (default: 10)

  ## Returns
    - List of activity records with associated actors
  """
  def get_company_activities(company_id, limit \\ 10) do
    Activity.get_company_activities(company_id, limit)
  end

  @doc """
  Gets recent activities for an employee.

  Retrieves the most recent activities related to a specific employee,
  ordered by date with newest first.

  ## Parameters
    - employee_id: The ID of the employee
    - limit: Maximum number of activities to retrieve (default: 10)

  ## Returns
    - List of activity records with associated actors
  """
  def get_employee_activities(employee_id, limit \\ 10) do
    Activity.get_entity_activities("employee", employee_id, limit)
  end

  @doc """
  Tracks activity for a general action with a user ID.

  This is a simplified tracking function that can be used when the actor is known
  by ID only and there's no specific entity being tracked besides metadata.

  ## Parameters
    - user_id: The ID of the user who performed the action
    - action: The description of the action performed
    - metadata: Additional contextual information (required)

  ## Returns
    - `{:ok, activity}` on successful recording
    - `{:error, changeset}` on validation failure
  """
  def track_activity(user_id, action, metadata) do
    Activity.track(%{
      action: action,
      entity_type: "system",
      entity_id: nil,
      changes: %{},
      metadata: metadata,
      actor_id: user_id,
      company_id: nil
    })
  end

  @doc """
  Tracks blog post activity.

  Records an action performed by a user on a blog post entity.
  Stores information about what was changed and any additional metadata.

  ## Parameters
    - action: The type of action performed (e.g., "post_create", "post_update")
    - post: The blog post entity that was affected by the action
    - actor: The user who performed the action
    - changes: Map of changes made during the action (default: empty map)
    - metadata: Additional contextual information (default: empty map)

  ## Returns
    - `{:ok, activity}` on successful recording
    - `{:error, changeset}` on validation failure
  """
  def track_blog_activity(action, post, actor, changes \\ %{}, metadata \\ %{}) do
    Activity.track(%{
      action: action,
      entity_type: "blog_post",
      entity_id: post.id,
      changes: changes,
      metadata: metadata,
      actor_id: actor.id,
      company_id: nil
    })
  end

  @doc """
  Gets recent activities for a blog post.

  Retrieves the most recent activities related to a specific blog post,
  ordered by date with newest first.

  ## Parameters
    - post_id: The ID of the blog post
    - limit: Maximum number of activities to retrieve (default: 10)

  ## Returns
    - List of activity records with associated actors
  """
  def get_blog_post_activities(post_id, limit \\ 10) do
    Activity.get_entity_activities("blog_post", post_id, limit)
  end
end
