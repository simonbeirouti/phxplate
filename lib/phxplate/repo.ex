defmodule Phxplate.Repo do
  use Ecto.Repo,
    otp_app: :phxplate,
    adapter: Ecto.Adapters.Postgres
end
