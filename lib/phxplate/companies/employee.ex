defmodule Phxplate.Companies.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :email, :string
    field :position, :string
    field :department, :string
    field :salary, :decimal

    belongs_to :company, Phxplate.Companies.Company
    belongs_to :profile, Phxplate.Accounts.Profile

    timestamps()
  end

  def changeset(employee, attrs, actor \\ nil) do
    changeset = employee
    |> cast(attrs, [:email, :position, :department, :salary, :company_id, :profile_id])
    |> validate_required([:email, :company_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:profile_id)

    if actor do
      action = if employee.id, do: "employee_update", else: "employee_create"
      changes = if employee.id, do: Map.take(attrs, [:position, :department, :salary]), else: %{}
      Phxplate.Tracking.track_employee_activity(action, employee, actor, changes)
    end

    changeset
  end
end
