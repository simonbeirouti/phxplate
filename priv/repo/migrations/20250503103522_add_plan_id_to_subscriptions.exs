defmodule Phxplate.Repo.Migrations.AddPlanIdToSubscriptions do
  use Ecto.Migration

  def change do
    alter table(:subscriptions) do
      add :plan_id, references(:plans, on_delete: :restrict)
    end

    create index(:subscriptions, [:plan_id])
  end
end
