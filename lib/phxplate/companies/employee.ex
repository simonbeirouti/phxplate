defmodule Phxplate.Companies.Employee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "employees" do
    field :first_name, :string
    field :last_name, :string
    field :email, :string
    field :phone, :string
    field :position, :string
    field :department, :string
    field :salary, :decimal

    belongs_to :company, Phxplate.Companies.Company

    timestamps()
  end

  def changeset(employee, attrs) do
    employee
    |> cast(attrs, [:first_name, :last_name, :email, :phone, :position, :department, :salary, :company_id])
    |> validate_required([:first_name, :last_name, :email, :company_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> foreign_key_constraint(:company_id)
  end
end
