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
    |> put_default_avatar()
  end

  defp put_default_avatar(changeset) do
    if get_field(changeset, :avatar_url) == nil do
      put_change(changeset, :avatar_url, default_avatar())
    else
      changeset
    end
  end

  def default_avatar do
    seed = :crypto.strong_rand_bytes(10) |> Base.encode16(case: :lower)
    "https://api.dicebear.com/7.x/avataaars/svg?seed=#{seed}"
  end
end
