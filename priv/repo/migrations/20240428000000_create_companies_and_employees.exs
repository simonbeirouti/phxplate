defmodule Phxplate.Repo.Migrations.CreateCompaniesAndEmployees do
  use Ecto.Migration

  def change do
    create table(:companies) do
      add :name, :string, null: false
      add :description, :text
      add :address, :string
      add :phone, :string
      add :email, :string
      add :plan, :string, null: false, default: "basic"

      timestamps()
    end

    create table(:employees) do
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :email, :string, null: false
      add :phone, :string
      add :position, :string
      add :department, :string
      add :salary, :decimal
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:employees, [:company_id])
    create unique_index(:employees, [:email])
  end
end
