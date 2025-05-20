defmodule Phxplate.Repo.Migrations.CreateCompaniesAndEmployees do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :string, null: false
      add :description, :text
      add :address, :string
      add :phone, :string
      add :email, :string
      add :logo, :string
      add :website, :string
      add :owner_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create table(:employees) do
      add :email, :string, null: false
      add :position, :string
      add :department, :string
      add :salary, :decimal
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:employees, [:company_id])
    create index(:companies, [:owner_id])
  end
end
