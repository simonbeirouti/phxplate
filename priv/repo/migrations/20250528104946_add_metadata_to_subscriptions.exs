defmodule Phxplate.Repo.Migrations.AddMetadataToSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add :metadata, :map, default: %{}
    end
  end
end
