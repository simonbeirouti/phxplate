defmodule Phxplate.Tracking.Activity do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "activities" do
    field :action, :string
    field :entity_type, :string
    field :entity_id, :integer
    field :changes, :map, default: %{}
    field :metadata, :map, default: %{}

    belongs_to :actor, Phxplate.Accounts.User
    belongs_to :company, Phxplate.Companies.Company

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(activity, attrs) do
    activity
    |> cast(attrs, [:action, :entity_type, :entity_id, :changes, :metadata, :actor_id, :company_id])
    |> validate_required([:action, :entity_type, :entity_id])
  end

  @doc """
  Creates a new activity record.
  """
  def track(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Phxplate.Repo.insert()
  end

  @doc """
  Gets activities for a specific entity.
  """
  def get_entity_activities(entity_type, entity_id, limit \\ 10) do
    from(a in __MODULE__,
      where: a.entity_type == ^entity_type and a.entity_id == ^entity_id,
      order_by: [desc: a.inserted_at],
      limit: ^limit,
      preload: [:actor]
    )
    |> Phxplate.Repo.all()
  end

  @doc """
  Gets activities for a company.
  """
  def get_company_activities(company_id, limit \\ 10) do
    from(a in __MODULE__,
      where: a.company_id == ^company_id,
      order_by: [desc: a.inserted_at],
      limit: ^limit,
      preload: [:actor]
    )
    |> Phxplate.Repo.all()
  end
end
