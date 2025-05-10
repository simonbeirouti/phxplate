defmodule Phxplate.Companies do
  import Ecto.Query, warn: false
  alias Phxplate.Repo
  alias Phxplate.Companies.Company
  alias Phxplate.Companies.Employee

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
end
