defmodule Phxplate.AI.Conversation do
  @moduledoc """
  Schema for AI chat conversations.

  This schema represents a conversation between a user and the AI assistant.
  Each conversation has a title, belongs to a user, and contains multiple messages.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Phxplate.Accounts.User
  alias Phxplate.AI.Message

  schema "ai_conversations" do
    field :title, :string
    field :system_prompt, :string
    field :archived, :boolean, default: false

    belongs_to :user, User
    has_many :messages, Message, on_delete: :delete_all

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a conversation.
  """
  def changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title, :system_prompt, :archived, :user_id])
    |> validate_required([:title, :user_id])
    |> validate_length(:title, min: 1, max: 255)
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  Changeset for updating just the title.
  """
  def title_changeset(conversation, attrs) do
    conversation
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
  end

  @doc """
  Changeset for archiving/unarchiving a conversation.
  """
  def archive_changeset(conversation, archived) do
    conversation
    |> cast(%{archived: archived}, [:archived])
    |> validate_required([:archived])
  end
end
