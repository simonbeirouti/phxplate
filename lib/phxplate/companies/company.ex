defmodule Phxplate.Companies.Company do
  use Ecto.Schema
  import Ecto.Changeset

  schema "companies" do
    field :name, :string
    field :description, :string
    field :address, :string
    field :phone, :string
    field :email, :string
    field :plan, :string, default: "basic"

    has_many :employees, Phxplate.Companies.Employee

    timestamps()
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :description, :address, :phone, :email, :plan])
    |> validate_required([:name])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:email)
  end
end
