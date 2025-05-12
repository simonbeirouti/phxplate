defmodule Phxplate.Companies do
  import Ecto.Query, warn: false
  alias Ecto.Multi
  alias Phxplate.Repo
  alias Phxplate.Companies.Company
  alias Phxplate.Companies.Employee
  alias Phxplate.Companies.Invitation

  def list_companies(opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    Company
    |> offset((^page - 1) * ^per_page)
    |> limit(^per_page)
    |> Repo.all()
  end

  def list_companies_by_owner(user_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 10)

    Company
    |> where(owner_id: ^user_id)
    |> offset((^page - 1) * ^per_page)
    |> limit(^per_page)
    |> Repo.all()
  end

  def get_company!(id), do: Repo.get!(Company, id)

  def create_company(attrs \\ %{}) do
    %Company{}
    |> Company.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, company} ->
        Phxplate.Tracking.track_company_activity("company_create", company, company.owner)
        {:ok, company}
      error -> error
    end
  end

  def update_company(%Company{} = company, attrs, actor \\ nil) do
    company
    |> Company.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_company} ->
        # Only track fields that have changed
        changed_fields = Enum.reduce(["name", "description", "address", "phone", "email", "plan", "logo", "website"], %{}, fn field, acc ->
          old_value = Map.get(company, String.to_atom(field))
          new_value = Map.get(attrs, field)
          if new_value && old_value != new_value do
            Map.put(acc, field, new_value)
          else
            acc
          end
        end)

        if map_size(changed_fields) > 0 do
          Phxplate.Tracking.track_company_activity("company_update", updated_company, actor || updated_company.owner, changed_fields)
        end

        {:ok, updated_company}
      error -> error
    end
  end

  def delete_company(%Company{} = company) do
    Repo.delete(company)
  end

  def list_employees do
    Repo.all(Employee)
  end

  def get_employee!(id), do: Repo.get!(Employee, id)

  def create_employee(attrs \\ %{}) do
    %Employee{}
    |> Employee.changeset(attrs)
    |> Repo.insert()
  end

  def update_employee(%Employee{} = employee, attrs) do
    employee
    |> Employee.changeset(attrs)
    |> Repo.update()
  end

  def delete_employee(%Employee{} = employee, actor \\ nil) do
    case Repo.delete(employee) do
      {:ok, deleted_employee} ->
        if actor do
          Phxplate.Tracking.track_company_activity(
            "employee_delete",
            %{id: deleted_employee.company_id},
            actor,
            %{"employee_email" => deleted_employee.email}
          )
        end
        {:ok, deleted_employee}
      error -> error
    end
  end

  def get_company_employees(%Company{} = company) do
    company
    |> Ecto.assoc(:employees)
    |> Repo.all()
  end

  def count_companies do
    Repo.aggregate(Company, :count, :id)
  end

  def count_employees do
    Repo.aggregate(Employee, :count, :id)
  end

  @doc """
  Sends an invitation to join a company.

  ## Parameters
    - company: The company struct
    - email: The email address to send the invitation to
    - inviter: The user sending the invitation
  """
  def invite_to_company(%Company{} = company, email, inviter) do
    token = Phoenix.Token.sign(PhxplateWeb.Endpoint, "company_invitation", %{
      company_id: company.id,
      email: email
    })

    invitation_attrs = %{
      email: email,
      token: token,
      company_id: company.id,
      inviter_id: inviter.id
    }

    # Create the invitation record
    with {:ok, invitation} <- create_invitation(invitation_attrs),
         invitation_url = PhxplateWeb.Endpoint.url() <> "/companies/invitations/#{token}",
         {:ok, _email} <- Phxplate.Accounts.UserNotifier.deliver_company_invitation(email, company, invitation_url) do
      # Track the invitation activity
      Phxplate.Tracking.track_company_activity(
        "employee_invite",
        company,
        inviter,
        %{"invited_email" => email}
      )
      {:ok, invitation}
    else
      {:error, changeset} -> {:error, changeset}
      error -> error
    end
  end

  @doc """
  Creates a company invitation.
  """
  def create_invitation(attrs) do
    %Invitation{}
    |> Invitation.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets a pending invitation by token.
  """
  def get_invitation_by_token(token) do
    Invitation
    |> where([i], i.token == ^token and is_nil(i.accepted_at))
    |> Repo.one()
  end

  @doc """
  Lists all pending invitations for a company.
  """
  def list_pending_invitations(%Company{} = company) do
    Invitation
    |> where([i], i.company_id == ^company.id and is_nil(i.accepted_at))
    |> preload([:inviter])
    |> Repo.all()
  end

  @doc """
  Deletes a company invitation.
  """
  def delete_invitation(%Invitation{} = invitation) do
    Repo.delete(invitation)
  end

  @doc """
  Accepts a company invitation.
  """
  def accept_invitation(%Invitation{} = invitation, user) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Create the employee record
    employee_attrs = %{
      email: user.email,
      company_id: invitation.company_id,
      user_id: user.id
    }

    Multi.new()
    |> Multi.update(:invitation, Invitation.changeset(invitation, %{accepted_at: now}))
    |> Multi.insert(:employee, Employee.changeset(%Employee{}, employee_attrs))
    |> Repo.transaction()
    |> case do
      {:ok, %{employee: employee}} -> {:ok, employee}
      {:error, _failed_operation, failed_value, _changes_so_far} -> {:error, failed_value}
    end
  end

  @doc """
  Verifies and processes a company invitation token.
  """
  def verify_invitation_token(token) do
    case Phoenix.Token.verify(PhxplateWeb.Endpoint, "company_invitation", token, max_age: 24 * 3600) do
      {:ok, %{company_id: company_id, email: email}} ->
        {:ok, %{company_id: company_id, email: email}}
      error -> error
    end
  end
end
