defmodule Phxplate.Repo.Migrations.AddRoleToUsers do
  use Ecto.Migration

  def change do
    execute "CREATE TYPE user_role AS ENUM ('basic', 'admin', 'super_admin')", ""

    alter table(:users) do
      add :role, :user_role, null: false, default: "basic"
    end

    create index(:users, [:role])
  end
end
