defmodule Phxplate.Repo.Migrations.AddDeviceInfoToChatSessions do
  use Ecto.Migration

  def change do
    alter table(:chat_sessions) do
      add :device_os, :string
      add :device_browser, :string
      add :device_type, :string
      add :user_agent, :text
      add :screen_resolution, :string
      add :timezone, :string
      add :language, :string
      add :ip_address, :string
    end

    create index(:chat_sessions, [:device_os])
    create index(:chat_sessions, [:device_browser])
    create index(:chat_sessions, [:device_type])
  end
end
