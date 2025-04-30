defmodule Phxplate.Accounts.Profile do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder, only: [:id, :first_name, :last_name, :bio, :avatar_url, :phone, :location, :website, :social_links, :user_id, :inserted_at, :updated_at]}

  schema "profiles" do
    field :first_name, :string
    field :last_name, :string
    field :bio, :string
    field :avatar_url, :string
    field :phone, :string
    field :location, :string
    field :website, :string
    field :social_links, :map, default: %{}

    belongs_to :user, Phxplate.Accounts.User

    timestamps()
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:first_name, :last_name, :bio, :avatar_url, :phone, :location, :website, :social_links, :user_id])
    |> validate_required([:user_id])
    |> foreign_key_constraint(:user_id)
  end
end
