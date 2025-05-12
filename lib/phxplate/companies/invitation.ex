defmodule Phxplate.Companies.Invitation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "company_invitations" do
    field :email, :string
    field :token, :string
    field :accepted_at, :utc_datetime

    belongs_to :company, Phxplate.Companies.Company
    belongs_to :inviter, Phxplate.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(invitation, attrs) do
    invitation
    |> cast(attrs, [:email, :token, :accepted_at, :company_id, :inviter_id])
    |> validate_required([:email, :token, :company_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint([:company_id, :email], message: "already has a pending invitation")
    |> unique_constraint(:token)
  end
end
