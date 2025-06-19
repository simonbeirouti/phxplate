defmodule Phxplate.Repo.Migrations.AddSidebarStateToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :sidebar_state, :string, default: "expanded", null: false
    end

    create index(:users, [:sidebar_state])
  end
end
