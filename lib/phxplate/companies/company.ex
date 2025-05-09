defmodule Phxplate.Companies.Company do
  use Ecto.Schema
  import Ecto.Changeset
  alias Phxplate.Accounts.User

  schema "companies" do
    field :name, :string
    field :description, :string
    field :address, :string
    field :phone, :string
    field :email, :string
    field :plan, :string, default: "basic"
    field :logo, :string
    field :website, :string

    has_many :employees, Phxplate.Companies.Employee
    belongs_to :owner, User

    timestamps()
  end

  @doc false
  def changeset(company, attrs) do
    company
    |> cast(attrs, [:name, :description, :address, :phone, :email, :plan, :logo, :website, :owner_id])
    |> validate_required([:name, :owner_id])
    |> validate_owner()
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:email)
  end

  @doc """
  Validates that the owner is an admin user.
  """
  def validate_owner(changeset) do
    case get_field(changeset, :owner_id) do
      nil -> changeset
      owner_id ->
        case Phxplate.Repo.get(User, owner_id) do
          %User{role: :admin} -> changeset
          _ -> add_error(changeset, :owner_id, "must be an admin user")
        end
    end
  end
end
