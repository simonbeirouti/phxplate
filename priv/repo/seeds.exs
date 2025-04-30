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
alias Phxplate.Companies
alias Phxplate.Companies.Company
alias Phxplate.Companies.Employee
alias Phxplate.Accounts.User
alias Phxplate.Accounts.Profile

# Store all created records
created_data = %{
  super_admins: [],
  admins: [],
  basic_users: [],
  companies: [],
  employees: [],
  profiles: []
}

# Clear existing data
Repo.delete_all(Phxplate.Accounts.UserToken)
Repo.delete_all(Profile)
Repo.delete_all(Employee)
Repo.delete_all(Company)
Repo.delete_all(User)

# Create super admins
created_data = Enum.reduce(1..1, created_data, fn _, acc ->
  user = User.registration_changeset(%User{}, %{
    email: Faker.Internet.email(),
    password: "password1234",
    role: :super_admin
  })
  |> Repo.insert!()

  # Create profile for super admin
  profile = Repo.insert!(%Profile{
    first_name: Faker.Person.first_name(),
    last_name: Faker.Person.last_name(),
    bio: Faker.Lorem.paragraph(),
    avatar_url: Faker.Avatar.image_url(),
    phone: Faker.Phone.EnUs.phone(),
    location: Faker.Address.city(),
    website: Faker.Internet.url(),
    social_links: %{
      twitter: Faker.Internet.url(),
      linkedin: Faker.Internet.url(),
      github: Faker.Internet.url()
    },
    user_id: user.id
  })

  acc
  |> Map.update!(:super_admins, &[%{id: user.id, email: user.email, role: user.role, profile: profile} | &1])
  |> Map.update!(:profiles, &[profile | &1])
end)

# Create admins
created_data = Enum.reduce(1..2, created_data, fn _, acc ->
  user = User.registration_changeset(%User{}, %{
    email: Faker.Internet.email(),
    password: "password1234",
    role: :admin
  })
  |> Repo.insert!()

  # Create profile for admin
  profile = Repo.insert!(%Profile{
    first_name: Faker.Person.first_name(),
    last_name: Faker.Person.last_name(),
    bio: Faker.Lorem.paragraph(),
    avatar_url: Faker.Avatar.image_url(),
    phone: Faker.Phone.EnUs.phone(),
    location: Faker.Address.city(),
    website: Faker.Internet.url(),
    social_links: %{
      twitter: Faker.Internet.url(),
      linkedin: Faker.Internet.url(),
      github: Faker.Internet.url()
    },
    user_id: user.id
  })

  acc
  |> Map.update!(:admins, &[%{id: user.id, email: user.email, role: user.role, profile: profile} | &1])
  |> Map.update!(:profiles, &[profile | &1])
end)

# Create basic users
created_data = Enum.reduce(1..3, created_data, fn _, acc ->
  user = User.registration_changeset(%User{}, %{
    email: Faker.Internet.email(),
    password: "password1234",
    role: :basic
  })
  |> Repo.insert!()

  # Create profile for basic user
  profile = Repo.insert!(%Profile{
    first_name: Faker.Person.first_name(),
    last_name: Faker.Person.last_name(),
    bio: Faker.Lorem.paragraph(),
    avatar_url: Faker.Avatar.image_url(),
    phone: Faker.Phone.EnUs.phone(),
    location: Faker.Address.city(),
    website: Faker.Internet.url(),
    social_links: %{
      twitter: Faker.Internet.url(),
      linkedin: Faker.Internet.url(),
      github: Faker.Internet.url()
    },
    user_id: user.id
  })

  acc
  |> Map.update!(:basic_users, &[%{id: user.id, email: user.email, role: user.role, profile: profile} | &1])
  |> Map.update!(:profiles, &[profile | &1])
end)

# Create companies with employees
created_data = Enum.reduce(1..2, created_data, fn _, acc ->
  company = Repo.insert!(%Company{
    name: Faker.Company.name(),
    description: Faker.Company.bs(),
    address: Faker.Address.street_address(),
    phone: Faker.Phone.EnUs.phone(),
    email: Faker.Internet.email(),
    logo: Faker.Avatar.image_url(),
    website: Faker.Internet.url(),
    plan: "basic"
  })

  company_data = %{
    id: company.id,
    name: company.name,
    description: company.description,
    address: company.address,
    phone: company.phone,
    email: company.email,
    plan: company.plan,
    logo: company.logo,
    website: company.website
  }

  # Create employees for each company
  {employees, acc} = Enum.reduce(1..2, {[], acc}, fn _, {employees, acc} ->
    employee = Repo.insert!(%Employee{
      first_name: Faker.Person.first_name(),
      last_name: Faker.Person.last_name(),
      email: Faker.Internet.email(),
      phone: Faker.Phone.EnUs.phone(),
      position: Faker.Company.bs(),
      department: Faker.Commerce.department(),
      salary: Enum.random(30_000..150_000),
      company_id: company.id
    })

    employee_data = %{
      id: employee.id,
      first_name: employee.first_name,
      last_name: employee.last_name,
      email: employee.email,
      phone: employee.phone,
      position: employee.position,
      department: employee.department,
      salary: employee.salary,
      company_id: employee.company_id
    }

    {[employee_data | employees], Map.update!(acc, :employees, &[employee_data | &1])}
  end)

  Map.update!(acc, :companies, &[Map.put(company_data, :employees, employees) | &1])
end)

# Write the data to a JSON file
json_data = Jason.encode!(created_data, pretty: true)
File.write!("priv/repo/seeds.json", json_data)

IO.puts("Seed data created successfully and written to seeds.json!")
