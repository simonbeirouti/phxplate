# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Phxplate.Repo.insert!(%Phxplate.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Phxplate.Accounts
alias Phxplate.Repo

# Clear existing data
Repo.delete_all(Phxplate.Accounts.UserToken)
Repo.delete_all(Phxplate.Accounts.User)

# Create users with different roles and states
users = [
  # Super Admin users
  %{
    email: "superadmin@example.com",
    password: "password1234",
    role: :super_admin,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  },

  # Admin users
  %{
    email: "admin@example.com",
    password: "password1234",
    role: :admin,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  },
  %{
    email: "admin2@example.com",
    password: "password1234",
    role: :admin,
    confirmed_at: nil  # Unconfirmed admin
  },

  # Basic users
  %{
    email: "user@example.com",
    password: "password1234",
    role: :basic,
    confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)
  },
  %{
    email: "user2@example.com",
    password: "password1234",
    role: :basic,
    confirmed_at: nil  # Unconfirmed user
  },
  %{
    email: "user3@example.com",
    password: "password1234",
    role: :basic,
    confirmed_at: DateTime.utc_now() |> DateTime.add(-86400, :second) |> DateTime.truncate(:second)  # Confirmed yesterday
  }
]

# Register users and collect results
results = Enum.map(users, fn user_attrs ->
  case Accounts.register_user(user_attrs) do
    {:ok, user} ->
      # Update the role and confirmation status
      user
      |> Ecto.Changeset.change(%{
        role: user_attrs.role,
        confirmed_at: user_attrs.confirmed_at
      })
      |> Repo.update!()
      |> Map.take([:email, :role, :confirmed_at])
      |> Map.put(:confirmed, not is_nil(user_attrs.confirmed_at))
    {:error, changeset} ->
      IO.puts("Failed to create user #{user_attrs.email}: #{inspect(changeset.errors)}")
      nil
  end
end)

# Filter out any failed creations
results = Enum.filter(results, &(&1 != nil))

# Write results to JSON file
json_data = Jason.encode!(results, pretty: true)
File.write!("priv/repo/seeds.json", json_data)

IO.puts("Created #{length(results)} users and saved to seeds.json")
