defmodule Phxplate.Bookmarks.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset
  alias Phxplate.Accounts.User
  alias Phxplate.Companies.Company

  schema "bookmarks" do
    belongs_to :user, User
    belongs_to :company, Company

    timestamps()
  end

  @doc false
  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:user_id, :company_id])
    |> validate_required([:user_id, :company_id])
    |> unique_constraint([:user_id, :company_id], message: "Company already bookmarked")
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:company_id)
  end
end
