defmodule Phxplate.Repo.Migrations.AddProfileIdToEmployees do
  use Ecto.Migration

  def change do
    alter table(:employees) do
      add :profile_id, references(:profiles, on_delete: :nilify_all)
    end

    create index(:employees, [:profile_id])
  end
end
