defmodule Phxplate.FeatureRequests do
  @moduledoc """
  The FeatureRequests context.
  
  This context handles the creation and management of feature requests
  submitted by users.
  """

  import Ecto.Query, warn: false
  alias Phxplate.Repo
  alias Phxplate.FeatureRequests.FeatureRequest

  @doc """
  Returns the list of feature_requests.

  ## Examples

      iex> list_feature_requests()
      [%FeatureRequest{}, ...]

  """
  def list_feature_requests do
    Repo.all(FeatureRequest)
  end

  @doc """
  Gets a single feature_request.

  Raises `Ecto.NoResultsError` if the Feature request does not exist.

  ## Examples

      iex> get_feature_request!(123)
      %FeatureRequest{}

      iex> get_feature_request!(456)
      ** (Ecto.NoResultsError)

  """
  def get_feature_request!(id), do: Repo.get!(FeatureRequest, id)

  @doc """
  Creates a feature_request.

  ## Examples

      iex> create_feature_request(%{field: value})
      {:ok, %FeatureRequest{}}

      iex> create_feature_request(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_feature_request(attrs \\  %{}) do
    %FeatureRequest{}
    |> FeatureRequest.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a feature_request.

  ## Examples

      iex> update_feature_request(feature_request, %{field: new_value})
      {:ok, %FeatureRequest{}}

      iex> update_feature_request(feature_request, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_feature_request(%FeatureRequest{} = feature_request, attrs) do
    feature_request
    |> FeatureRequest.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a feature_request.

  ## Examples

      iex> delete_feature_request(feature_request)
      {:ok, %FeatureRequest{}}

      iex> delete_feature_request(feature_request)
      {:error, %Ecto.Changeset{}}

  """
  def delete_feature_request(%FeatureRequest{} = feature_request) do
    Repo.delete(feature_request)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking feature_request changes.

  ## Examples

      iex> change_feature_request(feature_request)
      %Ecto.Changeset{data: %FeatureRequest{}}

  """
  def change_feature_request(%FeatureRequest{} = feature_request, attrs \\ %{}) do
    FeatureRequest.changeset(feature_request, attrs)
  end
end
