defmodule Phxplate.Repo.Migrations.CreateAiConversationsAndMessages do
  use Ecto.Migration

  def change do
    # Create enum for message roles
    execute "CREATE TYPE ai_message_role AS ENUM ('user', 'assistant', 'system')", ""

    create table(:ai_conversations) do
      add :title, :string, null: false
      add :system_prompt, :text
      add :archived, :boolean, default: false, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create table(:ai_messages) do
      add :role, :ai_message_role, null: false
      add :content, :text, null: false
      add :metadata, :map, default: %{}
      add :conversation_id, references(:ai_conversations, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:ai_conversations, [:user_id])
    create index(:ai_conversations, [:archived])
    create index(:ai_conversations, [:inserted_at])
    create index(:ai_messages, [:conversation_id])
    create index(:ai_messages, [:inserted_at])
  end
end
