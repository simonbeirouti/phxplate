defmodule Phxplate.Bookmarks do
  @moduledoc """
  The Bookmarks context.
  """

  import Ecto.Query, warn: false
  alias Phxplate.Repo
  alias Phxplate.Bookmarks.Bookmark

  @doc """
  Returns the list of bookmarks for a user.
  """
  def list_user_bookmarks(user_id) do
    Bookmark
    |> where(user_id: ^user_id)
    |> preload(:company)
    |> Repo.all()
  end

  @doc """
  Gets a single bookmark by user and company.
  """
  def get_bookmark(user_id, company_id) do
    Bookmark
    |> where(user_id: ^user_id, company_id: ^company_id)
    |> Repo.one()
  end

  @doc """
  Creates a bookmark.
  """
  def create_bookmark(attrs \\ %{}) do
    %Bookmark{}
    |> Bookmark.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a bookmark.
  """
  def delete_bookmark(%Bookmark{} = bookmark) do
    Repo.delete(bookmark)
  end

  @doc """
  Returns true if the user has bookmarked the company.
  """
  def bookmarked?(user_id, company_id) do
    Bookmark
    |> where(user_id: ^user_id, company_id: ^company_id)
    |> Repo.exists?()
  end

  @doc """
  Returns the count of bookmarks for a user.
  """
  def count_user_bookmarks(user_id) do
    Bookmark
    |> where(user_id: ^user_id)
    |> Repo.aggregate(:count, :id)
  end
end
