defmodule RiceMill.AccountsCSVImportTest do
  use RiceMill.DataCase

  alias RiceMill.Accounts
  alias RiceMill.Accounts.User

  describe "import_users_from_csv/3" do
    setup do
      # Create a tenant for testing
      tenant = RiceMill.AccountsFixtures.tenant_fixture()

      # Create super admin and company admin users
      super_admin = RiceMill.AccountsFixtures.user_fixture(%{role: :super_admin, tenant_id: nil})

      company_admin =
        RiceMill.AccountsFixtures.user_fixture(%{role: :company_admin, tenant_id: tenant.id})

      %{tenant: tenant, super_admin: super_admin, company_admin: company_admin}
    end

    test "successfully imports valid users from CSV", %{tenant: tenant, super_admin: super_admin} do
      csv_content = """
      email,role,name,contact_phone
      john.doe@example.com,operator,John Doe,1234567890
      jane.smith@example.com,viewer,Jane Smith,0987654321
      """

      assert {:ok, summary} = Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)

      assert summary.total_rows == 2
      assert summary.successful == 2
      assert summary.failed == 0
      assert length(summary.created_users) == 2
      assert length(summary.errors) == 0

      # Verify users were created
      assert %User{} = Accounts.get_user_by_email("john.doe@example.com")
      assert %User{} = Accounts.get_user_by_email("jane.smith@example.com")
    end

    test "handles mixed valid and invalid CSV data", %{
      tenant: tenant,
      company_admin: company_admin
    } do
      csv_content = """
      email,role,name,contact_phone
      valid.user@example.com,operator,Valid User,1234567890
      invalid.email@,operator,Bad Email,
      duplicate@example.com,viewer,Duplicate User,1234567890
      duplicate@example.com,viewer,Duplicate User 2,0987654321
      """

      # Create a user with the duplicate email first
      RiceMill.AccountsFixtures.user_fixture(%{
        email: "duplicate@example.com",
        tenant_id: tenant.id
      })

      assert {:ok, summary} =
               Accounts.import_users_from_csv(csv_content, tenant.id, company_admin)

      assert summary.total_rows == 4
      assert summary.successful == 1
      assert summary.failed == 3
      assert length(summary.created_users) == 1
      # Fixed: should be 3 errors, not 2
      assert length(summary.errors) == 3

      # Verify only the valid user was created
      assert %User{} = Accounts.get_user_by_email("valid.user@example.com")
      refute Accounts.get_user_by_email("invalid.email@")

      # Check error details
      assert Enum.any?(summary.errors, fn error ->
               error.email == "invalid.email@" && error.error =~ "Invalid email format"
             end)

      assert Enum.any?(summary.errors, fn error ->
               error.email == "duplicate@example.com" && error.error =~ "Email already exists"
             end)
    end

    test "rejects unauthorized users", %{tenant: tenant} do
      # Create a regular user (not admin)
      regular_user =
        RiceMill.AccountsFixtures.user_fixture(%{role: :operator, tenant_id: tenant.id})

      csv_content = """
      email,role,name
      test@example.com,operator,Test User
      """

      assert {:error, :unauthorized} =
               Accounts.import_users_from_csv(csv_content, tenant.id, regular_user)
    end

    test "rejects company admin from importing to different tenant", %{
      tenant: tenant,
      company_admin: company_admin
    } do
      # Create another tenant
      other_tenant = RiceMill.AccountsFixtures.tenant_fixture()

      csv_content = """
      email,role,name
      test@example.com,operator,Test User
      """

      assert {:error, :unauthorized} =
               Accounts.import_users_from_csv(csv_content, other_tenant.id, company_admin)
    end

    test "handles invalid CSV format" do
      # Use truly invalid CSV format (unmatched quotes)
      csv_content = """
      email,role,name
      "test@example.com,operator,Test User
      """

      tenant = RiceMill.AccountsFixtures.tenant_fixture()
      super_admin = RiceMill.AccountsFixtures.user_fixture(%{role: :super_admin, tenant_id: nil})

      assert {:error, :invalid_csv_format} =
               Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)
    end

    test "handles missing required headers", %{tenant: tenant, super_admin: super_admin} do
      csv_content = """
      name,contact_phone
      John Doe,1234567890
      """

      assert {:error, {:missing_headers, ["email", "role"]}} =
               Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)
    end

    test "handles empty CSV", %{tenant: tenant, super_admin: super_admin} do
      csv_content = ""

      assert {:error, :empty_csv} =
               Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)
    end

    test "validates role restrictions for import", %{tenant: tenant, super_admin: super_admin} do
      csv_content = """
      email,role,name
      admin@example.com,company_admin,Admin User
      super@example.com,super_admin,Super Admin
      """

      assert {:ok, summary} = Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)

      # Should fail for invalid roles
      assert summary.total_rows == 2
      assert summary.successful == 0
      assert summary.failed == 2
      assert length(summary.errors) == 2

      assert Enum.all?(summary.errors, fn error ->
               error.error =~ "Role must be 'operator' or 'viewer'"
             end)
    end

    test "generates temporary passwords for imported users", %{
      tenant: tenant,
      company_admin: company_admin
    } do
      csv_content = """
      email,role,name
      temp.pass@example.com,operator,Temp Pass User
      """

      assert {:ok, summary} =
               Accounts.import_users_from_csv(csv_content, tenant.id, company_admin)

      assert length(summary.created_users) == 1
      created_user = hd(summary.created_users)

      # User should require password reset (indicating a temporary password was generated)
      assert created_user.password_reset_required == true

      # Verify the user was created successfully and can be retrieved
      retrieved_user = Accounts.get_user_by_email("temp.pass@example.com")
      assert retrieved_user != nil
      assert retrieved_user.role == :operator
      assert retrieved_user.name == "Temp Pass User"
    end
  end

  describe "validate_csv_import/3" do
    setup do
      tenant = RiceMill.AccountsFixtures.tenant_fixture()
      super_admin = RiceMill.AccountsFixtures.user_fixture(%{role: :super_admin, tenant_id: nil})

      company_admin =
        RiceMill.AccountsFixtures.user_fixture(%{role: :company_admin, tenant_id: tenant.id})

      regular_user =
        RiceMill.AccountsFixtures.user_fixture(%{role: :operator, tenant_id: tenant.id})

      %{
        tenant: tenant,
        super_admin: super_admin,
        company_admin: company_admin,
        regular_user: regular_user
      }
    end

    test "validates authorization for super admin", %{tenant: tenant, super_admin: super_admin} do
      parsed_data = [%{"email" => "test@example.com", "role" => "operator"}]

      assert {:ok, validation_result} =
               Accounts.validate_csv_import(parsed_data, tenant.id, super_admin)

      assert validation_result.total_rows == 1
      assert length(validation_result.valid_rows) == 1
      assert length(validation_result.invalid_rows) == 0
    end

    test "validates authorization for company admin", %{
      tenant: tenant,
      company_admin: company_admin
    } do
      parsed_data = [%{"email" => "test@example.com", "role" => "operator"}]

      assert {:ok, validation_result} =
               Accounts.validate_csv_import(parsed_data, tenant.id, company_admin)

      assert validation_result.total_rows == 1
      assert length(validation_result.valid_rows) == 1
      assert length(validation_result.invalid_rows) == 0
    end

    test "rejects unauthorized users", %{tenant: tenant, regular_user: regular_user} do
      parsed_data = [%{"email" => "test@example.com", "role" => "operator"}]

      assert {:error, :unauthorized} =
               Accounts.validate_csv_import(parsed_data, tenant.id, regular_user)
    end

    test "validates CSV data with various validation rules", %{
      tenant: tenant,
      super_admin: super_admin
    } do
      parsed_data = [
        %{"email" => "valid@example.com", "role" => "operator", "name" => "Valid User"},
        %{"email" => "invalid-email", "role" => "operator", "name" => "Invalid Email"},
        %{"email" => "valid2@example.com", "role" => "admin", "name" => "Invalid Role"},
        %{"email" => "", "role" => "operator", "name" => "Missing Email"}
      ]

      assert {:ok, validation_result} =
               Accounts.validate_csv_import(parsed_data, tenant.id, super_admin)

      assert validation_result.total_rows == 4
      assert length(validation_result.valid_rows) == 1
      assert length(validation_result.invalid_rows) == 3

      # Check specific error details
      invalid_rows = validation_result.invalid_rows
      assert Enum.any?(invalid_rows, fn error -> error.error == "Invalid email format" end)

      assert Enum.any?(invalid_rows, fn error ->
               error.error == "Role must be 'operator' or 'viewer'"
             end)

      assert Enum.any?(invalid_rows, fn error -> error.error == "Email is required" end)
    end
  end

  describe "CSV parsing edge cases" do
    test "handles CSV with quoted fields containing commas" do
      csv_content = """
      email,role,name,contact_phone
      "john.doe@example.com",operator,"John, Doe",1234567890
      "jane.smith@example.com",viewer,"Jane Smith",0987654321
      """

      tenant = RiceMill.AccountsFixtures.tenant_fixture()
      super_admin = RiceMill.AccountsFixtures.user_fixture(%{role: :super_admin, tenant_id: nil})

      assert {:ok, summary} = Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)
      assert summary.successful == 2

      # Verify the name with comma was parsed correctly
      user = Accounts.get_user_by_email("john.doe@example.com")
      assert user.name == "John, Doe"
    end

    test "handles CSV with extra whitespace" do
      csv_content = """
      email,role,name
      john.doe@example.com  ,  operator  ,  John Doe
      """

      tenant = RiceMill.AccountsFixtures.tenant_fixture()
      super_admin = RiceMill.AccountsFixtures.user_fixture(%{role: :super_admin, tenant_id: nil})

      assert {:ok, summary} = Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)
      assert summary.successful == 1

      user = Accounts.get_user_by_email("john.doe@example.com")
      assert user.role == :operator
      assert user.name == "John Doe"
    end

    test "handles CSV with optional fields missing" do
      csv_content = """
      email,role
      minimal@example.com,operator
      """

      tenant = RiceMill.AccountsFixtures.tenant_fixture()
      super_admin = RiceMill.AccountsFixtures.user_fixture(%{role: :super_admin, tenant_id: nil})

      assert {:ok, summary} = Accounts.import_users_from_csv(csv_content, tenant.id, super_admin)
      assert summary.successful == 1

      user = Accounts.get_user_by_email("minimal@example.com")
      assert user.role == :operator
      # Should be nil when not provided
      assert user.name == nil
      # Should be nil when not provided
      assert user.contact_phone == nil
    end
  end
end
