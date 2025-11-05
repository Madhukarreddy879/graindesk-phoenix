# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     RiceMill.Repo.insert!(%RiceMill.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

import Ecto.Query

alias RiceMill.Repo
alias RiceMill.Accounts
alias RiceMill.Accounts.{User, Tenant}
alias RiceMill.Inventory

# Create Super Admin User
# Uses environment variables for email and password
# SUPER_ADMIN_EMAIL - required, no default
# SUPER_ADMIN_PASSWORD - required, no default (minimum 12 characters)
IO.puts("Checking for super admin user...")

super_admin_email = System.get_env("SUPER_ADMIN_EMAIL")
super_admin_password = System.get_env("SUPER_ADMIN_PASSWORD")

unless super_admin_email && super_admin_password do
  IO.puts("\n" <> String.duplicate("=", 60))
  IO.puts("ERROR: Super admin credentials not provided!")
  IO.puts(String.duplicate("=", 60))
  IO.puts("\nPlease set the following environment variables:")
  IO.puts("  SUPER_ADMIN_EMAIL - Email address for super admin")
  IO.puts("  SUPER_ADMIN_PASSWORD - Password (minimum 12 characters)")
  IO.puts("\nExample:")
  IO.puts("  SUPER_ADMIN_EMAIL=\"admin@example.com\" \\")
  IO.puts("  SUPER_ADMIN_PASSWORD=\"your-secure-password-here\" \\")
  IO.puts("  mix run priv/repo/seeds.exs")
  IO.puts(String.duplicate("=", 60) <> "\n")
  System.halt(1)
end

if String.length(super_admin_password) < 12 do
  IO.puts("\n" <> String.duplicate("=", 60))
  IO.puts("ERROR: Super admin password must be at least 12 characters!")
  IO.puts(String.duplicate("=", 60) <> "\n")
  System.halt(1)
end

# Check if super admin already exists
existing_super_admin =
  from(u in User, where: u.role == :super_admin and u.email == ^super_admin_email)
  |> Repo.one()

if existing_super_admin do
  IO.puts("✓ Super admin already exists: #{existing_super_admin.email}")
else
  IO.puts("Creating super admin user...")

  super_admin =
    %User{}
    |> User.email_changeset(%{
      email: super_admin_email,
      role: :super_admin,
      tenant_id: nil,
      status: :active
    })
    |> User.password_changeset(%{password: super_admin_password})
    |> User.confirm_changeset()
    |> Repo.insert!()

  IO.puts("✓ Super admin created: #{super_admin.email}")
end

# Create Sample Tenant (only for development/demo purposes)
IO.puts("\nChecking for sample tenant...")

tenant =
  case Repo.get_by(Tenant, slug: "shri-krishna-rice-mill") do
    nil ->
      IO.puts("Creating sample tenant...")

      {:ok, tenant} =
        Accounts.create_tenant(%{
          name: "Shri Krishna Rice Mill",
          slug: "shri-krishna-rice-mill",
          active: true
        })

      IO.puts("✓ Tenant created: #{tenant.name}")
      tenant

    existing_tenant ->
      IO.puts("✓ Sample tenant already exists: #{existing_tenant.name}")
      existing_tenant
  end

# Create Tenant User (company_admin role)
IO.puts("\nChecking for sample tenant user...")

case Repo.get_by(User, email: "user@shrikrishna.com") do
  nil ->
    IO.puts("Creating tenant user...")

    _tenant_user =
      %User{}
      |> User.email_changeset(%{
        email: "user@shrikrishna.com",
        role: :company_admin,
        tenant_id: tenant.id,
        status: :active,
        name: "Company Admin"
      })
      |> User.password_changeset(%{password: "userpassword123"})
      |> User.confirm_changeset()
      |> Repo.insert!()

    IO.puts("✓ Tenant user created: user@shrikrishna.com")

  existing_user ->
    IO.puts("✓ Sample tenant user already exists: #{existing_user.email}")
end

# Create Sample Products (only if they don't exist)
IO.puts("\nChecking for sample products...")

products_data = [
  %{
    name: "Basmati Paddy",
    sku: "PADDY-BAS-001",
    category: "Paddy",
    unit: "quintal",
    price_per_quintal: Decimal.new("2500.00")
  },
  %{
    name: "Sona Masoori Paddy",
    sku: "PADDY-SM-001",
    category: "Paddy",
    unit: "quintal",
    price_per_quintal: Decimal.new("2200.00")
  },
  %{
    name: "IR64 Paddy",
    sku: "PADDY-IR64-001",
    category: "Paddy",
    unit: "quintal",
    price_per_quintal: Decimal.new("2000.00")
  },
  %{
    name: "Swarna Paddy",
    sku: "PADDY-SWR-001",
    category: "Paddy",
    unit: "quintal",
    price_per_quintal: Decimal.new("1900.00")
  },
  %{
    name: "Kolam Paddy",
    sku: "PADDY-KLM-001",
    category: "Paddy",
    unit: "quintal",
    price_per_quintal: Decimal.new("2100.00")
  }
]

products =
  Enum.map(products_data, fn product_attrs ->
    existing_product =
      from(p in RiceMill.Inventory.Product,
        where: p.tenant_id == ^tenant.id and p.sku == ^product_attrs.sku
      )
      |> Repo.one()

    case existing_product do
      nil ->
        {:ok, product} = Inventory.create_product(tenant.id, product_attrs)
        IO.puts("  ✓ Product created: #{product.name} (#{product.sku})")
        product

      existing_product ->
        IO.puts("  ✓ Product already exists: #{existing_product.name} (#{existing_product.sku})")
        existing_product
    end
  end)

IO.puts("\n✓ #{length(products)} products available")

# Create Sample Stock-In Entries (only for demo purposes)
# Skip if stock-in entries already exist for this tenant
existing_stock_ins_count =
  from(s in RiceMill.Inventory.StockIn, where: s.tenant_id == ^tenant.id)
  |> Repo.aggregate(:count)

if existing_stock_ins_count == 0 do
  IO.puts("\nCreating sample stock-in entries...")

  stock_ins_data = [
    %{
      product_id: Enum.at(products, 0).id,
      date: ~D[2024-10-15],
      farmer_name: "Ramesh Kumar",
      farmer_contact: "9876543210",
      vehicle_number: "MH-12-AB-1234",
      num_of_bags: 50,
      net_weight_per_bag_kg: Decimal.new("45.5"),
      price_per_quintal: Decimal.new("2500.00")
    },
    %{
      product_id: Enum.at(products, 1).id,
      date: ~D[2024-10-16],
      farmer_name: "Suresh Patil",
      farmer_contact: "9876543211",
      vehicle_number: "MH-12-CD-5678",
      num_of_bags: 40,
      net_weight_per_bag_kg: Decimal.new("48.0"),
      price_per_quintal: Decimal.new("2200.00")
    },
    %{
      product_id: Enum.at(products, 2).id,
      date: ~D[2024-10-17],
      farmer_name: "Ganesh Deshmukh",
      farmer_contact: "9876543212",
      vehicle_number: "MH-12-EF-9012",
      num_of_bags: 60,
      net_weight_per_bag_kg: Decimal.new("46.0"),
      price_per_quintal: Decimal.new("2000.00")
    },
    %{
      product_id: Enum.at(products, 0).id,
      date: ~D[2024-10-18],
      farmer_name: "Ramesh Kumar",
      farmer_contact: "9876543210",
      vehicle_number: "MH-12-AB-1234",
      num_of_bags: 45,
      net_weight_per_bag_kg: Decimal.new("47.0"),
      price_per_quintal: Decimal.new("2500.00")
    },
    %{
      product_id: Enum.at(products, 3).id,
      date: ~D[2024-10-19],
      farmer_name: "Prakash Jadhav",
      farmer_contact: "9876543213",
      vehicle_number: "MH-12-GH-3456",
      num_of_bags: 55,
      net_weight_per_bag_kg: Decimal.new("44.5"),
      price_per_quintal: Decimal.new("1900.00")
    },
    %{
      product_id: Enum.at(products, 4).id,
      date: ~D[2024-10-20],
      farmer_name: "Vijay Shinde",
      farmer_contact: "9876543214",
      vehicle_number: "MH-12-IJ-7890",
      num_of_bags: 50,
      net_weight_per_bag_kg: Decimal.new("46.5"),
      price_per_quintal: Decimal.new("2100.00")
    }
  ]

  Enum.each(stock_ins_data, fn stock_in_attrs ->
    {:ok, stock_in} = Inventory.create_stock_in(tenant.id, stock_in_attrs)

    IO.puts("  ✓ Stock-in created: #{stock_in.farmer_name} - #{stock_in.total_quintals} quintals")
  end)

  IO.puts("\n✓ #{length(stock_ins_data)} stock-in entries created")
else
  IO.puts("\n✓ Stock-in entries already exist (#{existing_stock_ins_count} entries)")
end

IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("Database seeding completed successfully!")
IO.puts(String.duplicate("=", 60))
IO.puts("\nLogin Credentials:")
IO.puts("\n  Super Admin:")
IO.puts("    Email: #{super_admin_email}")
IO.puts("    Password: [provided via environment variable]")
IO.puts("\n  Company Admin (Shri Krishna Rice Mill):")
IO.puts("    Email: user@shrikrishna.com")
IO.puts("    Password: userpassword123")
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("\nNote: Change the demo company admin password after first login!")
IO.puts(String.duplicate("=", 60))
