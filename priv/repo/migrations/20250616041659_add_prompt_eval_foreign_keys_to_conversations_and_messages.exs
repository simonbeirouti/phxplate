defmodule Phxplate.Repo.Migrations.AddPromptForeignKeysToConversationsAndMessages do
  use Ecto.Migration

  def change do
    # Add foreign key constraints to ai_conversations table
    alter table(:ai_conversations) do
      modify :selected_prompt_id, references(:ai_prompts, on_delete: :nilify_all), from: :integer
    end

    # Add foreign key constraints to ai_messages table
    alter table(:ai_messages) do
      modify :prompt_id, references(:ai_prompts, on_delete: :nilify_all), from: :integer
    end

    # Add indexes for the foreign key columns
    create index(:ai_conversations, [:selected_prompt_id])
    create index(:ai_messages, [:prompt_id])
  end
end
