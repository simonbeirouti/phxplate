defmodule Phxplate.AI.Message do
  @moduledoc """
  Schema for AI chat messages.

  This schema represents individual messages within an AI conversation.
  Messages can be from either the user or the assistant.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Phxplate.AI.Conversation

  @roles [:user, :assistant, :system]

  schema "ai_messages" do
    field :role, Ecto.Enum, values: @roles
    field :content, :string
    field :metadata, :map, default: %{}

    belongs_to :conversation, Conversation

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset for creating or updating a message.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:role, :content, :metadata, :conversation_id])
    |> validate_required([:role, :content, :conversation_id])
    |> validate_inclusion(:role, @roles)
    |> validate_length(:content, min: 1)
    |> foreign_key_constraint(:conversation_id)
  end
end
