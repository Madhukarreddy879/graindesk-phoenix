# Implementation Plan

- [x] 1. Extend database schemas and run migrations
  - Create migration to extend users table with new fields (name, contact_phone, status, last_login_at, password_reset_required)
  - Create migration to update role enum from [:super_admin, :tenant_user] to [:super_admin, :company_admin, :operator, :viewer]
  - Update existing tenant_user roles to company_admin in migration
  - Create migration to extend tenants table with contact_email, contact_phone, and settings map
  - Create migration for user_invitations table with all required fields and indexes
  - Create migration for audit_logs table with all required fields and indexes
  - Run migrations and verify schema changes
  - _Requirements: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17_

- [x] 2. Update User and Tenant schemas with new fields and validations
  - Update User schema in lib/rice_mill/accounts/user.ex to include new fields (name, contact_phone, status, last_login_at, password_reset_required)
  - Update User role enum to include :company_admin, :operator, and :viewer
  - Add validation for status field (active/inactive)
  - Update email_changeset to handle new fields
  - Update Tenant schema in lib/rice_mill/accounts/tenant.ex to include contact_email, contact_phone, and settings
  - Add changeset validations for new tenant fields
  - _Requirements: 1, 2, 3, 4, 5, 6, 13, 14_

- [x] 3. Create UserInvitation schema and context functions
  - Create UserInvitation schema in lib/rice_mill/accounts/user_invitation.ex
  - Implement changeset with validations for email, role, tenant_id, token, expires_at
  - Add belongs_to associations for tenant and invited_by user
  - Create functions in Accounts context: create_invitation/3, get_invitation_by_token/1, accept_invitation/2
  - Implement secure token generation using :crypto.strong_rand_bytes
  - Add function to expire old invitations
  - _Requirements: 7, 12_

- [ ] 4. Create AuditLog schema and logging functions
  - Create AuditLog schema in lib/rice_mill/accounts/audit_log.ex
  - Implement changeset with validations for user_id, action, resource_type, changes
  - Add belongs_to associations for user and tenant
  - Create log_action/4 function in Accounts context to create audit entries
  - Create list_audit_logs/2 function with filtering by tenant, user, action, date range
  - Create get_user_activity/2 function for user-specific activity
  - _Requirements: 10, 11_

- [ ] 5. Create Authorization module for role-based access control
  - Create Authorization module in lib/rice_mill/accounts/authorization.ex
  - Implement can?/3 function for checking permissions based on role and resource
  - Implement helper functions: super_admin?/1, company_admin?/1, same_tenant?/2
  - Implement permission check functions: can_manage_users?/2, can_manage_tenants?/1, can_view_audit_logs?/2
  - Implement authorize!/3 function that raises on unauthorized access
  - Add authorization rules for all four roles (super_admin, company_admin, operator, viewer)
  - _Requirements: 6, 15_

- [x] 6. Extend Accounts context with user management functions
  - Add list_users/2 function with scope-based filtering
  - Add list_users_for_tenant/2 function for company admin use
  - Update get_user!/2 to accept scope parameter and enforce authorization
  - Add create_user/2 function with created_by_scope parameter and audit logging
  - Add update_user/3 function with authorization and audit logging
  - Add delete_user/2 function with authorization and audit logging
  - Add deactivate_user/2 and activate_user/2 functions with status management
  - Add update_last_login/1 function to track user login times
  - _Requirements: 4, 5, 8, 15_

- [ ] 7. Extend Accounts context with tenant management functions
  - Add list_tenants_with_stats/0 function to include user count and last activity
  - Add get_tenant_with_stats!/1 function for detailed tenant view
  - Add create_tenant_with_admin/3 function to create tenant and admin user in transaction
  - Add update_tenant/3 function with authorization
  - Add deactivate_tenant/2 and activate_tenant/2 functions
  - Add get_tenant_settings/1 and update_tenant_settings/3 functions
  - Add get_tenant_activity_metrics/1 function for activity monitoring
  - _Requirements: 1, 2, 3, 11, 14_

- [ ] 8. Implement password management functions
  - Add reset_user_password/2 function in Accounts context
  - Add generate_temporary_password/0 function to create secure random passwords
  - Add require_password_change/1 function to set password_reset_required flag
  - Update user authentication to check password_reset_required and redirect to password change
  - _Requirements: 9, 16_

- [ ] 9. Create RequireRole plug for route authorization
  - Create RequireRole plug in lib/rice_mill_web/plugs/require_role.ex
  - Implement init/1 and call/2 functions
  - Check user role against allowed roles list
  - Redirect to home page with error message if unauthorized
  - Log authorization failures in audit log
  - _Requirements: 6, 17_

- [ ] 10. Create LoadTenantContext plug for tenant data loading
  - Create LoadTenantContext plug in lib/rice_mill_web/plugs/load_tenant_context.ex
  - Load tenant record for current user's tenant_id
  - Assign current_tenant to conn for use in LiveViews
  - Handle nil tenant_id for super admins
  - _Requirements: 1, 14_

- [ ] 11. Update UserAuth module to track login activity
  - Modify log_in_user/3 function to call update_last_login/1
  - Add audit log entry for successful login
  - Add audit log entry for failed login attempts
  - Add audit log entry for logout
  - Update fetch_current_scope_for_user/2 to check user status (active/inactive)
  - _Requirements: 10, 16_

- [ ] 12. Extend UserNotifier with invitation and password reset emails
  - Add deliver_user_invitation/2 function to send invitation emails
  - Add deliver_password_reset/2 function to send temporary password emails
  - Add deliver_welcome_email/2 function for new user welcome
  - Create HTML email templates for each notification type
  - Include invitation acceptance URL with token
  - _Requirements: 7, 9_

- [ ] 13. Implement CSV bulk import functionality
  - Add import_users_from_csv/3 function in Accounts context
  - Add validate_csv_import/1 function to validate CSV data
  - Parse CSV with NimbleCSV library
  - Validate each row for required fields (email, role)
  - Create users in transaction with rollback on any error
  - Return summary with successful imports and errors
  - _Requirements: 12_

- [ ] 14. Create TenantLive.Index for super admin tenant management
  - Create LiveView at lib/rice_mill_web/live/admin/tenant_live/index.ex
  - Display table of all tenants with name, slug, status, user count, last activity
  - Add search functionality to filter by name or slug
  - Add "Create Tenant" button that opens modal form
  - Add activate/deactivate buttons for each tenant
  - Add link to tenant detail page
  - Implement handle_event for create, activate, deactivate actions
  - _Requirements: 1, 2, 11, 17_

- [ ] 15. Create TenantLive.Show for tenant details
  - Create LiveView at lib/rice_mill_web/live/admin/tenant_live/show.ex
  - Display tenant details (name, slug, contact info, settings)
  - Display list of users in tenant
  - Display activity metrics (total users, active users, last activity)
  - Add "Edit Tenant" button that opens modal form
  - Implement handle_event for update action
  - _Requirements: 1, 11, 14, 17_

- [ ] 16. Create TenantLive.FormComponent for tenant create/edit
  - Create form component at lib/rice_mill_web/live/admin/tenant_live/form_component.ex
  - Add fields for name, slug, contact_email, contact_phone
  - Add checkbox for active status
  - When creating tenant, include fields for admin user (email, password, name)
  - Validate slug uniqueness
  - Call create_tenant_with_admin/3 for new tenants
  - Display success message and close modal on save
  - _Requirements: 2, 3, 17_

- [ ] 17. Create AdminUserLive.Index for super admin user management
  - Create LiveView at lib/rice_mill_web/live/admin/user_live/index.ex
  - Display table of all users across all tenants
  - Add columns for email, name, role, tenant name, status, last login
  - Add search functionality to filter by email, tenant, or role
  - Add "Create User" button that opens modal form
  - Add edit, reset password, and delete buttons for each user
  - Implement handle_event for create, update, delete, reset_password actions
  - _Requirements: 15, 17_

- [ ] 18. Create AdminUserLive.FormComponent for user create/edit
  - Create form component at lib/rice_mill_web/live/admin/user_live/form_component.ex
  - Add fields for email, name, contact_phone, role, tenant_id, status
  - Add tenant selector dropdown for super admin
  - Add role selector with all four roles
  - Add password field for new users
  - Validate email uniqueness
  - Call create_user/2 or update_user/3 with audit logging
  - Display success message and close modal on save
  - _Requirements: 3, 5, 15, 17_

- [x] 19. Create UserManagementLive.Index for company admin user management
  - Create LiveView at lib/rice_mill_web/live/user_management_live/index.ex
  - Display table of users in current tenant only
  - Add columns for email, name, role, status, last login
  - Add search functionality to filter by email or role
  - Add "Invite User" button that opens invitation form
  - Add "Import Users" button that navigates to bulk import page
  - Add edit, reset password, activate/deactivate buttons for each user
  - Implement handle_event for update, reset_password, activate, deactivate actions
  - _Requirements: 4, 5, 8, 9, 17_

- [x] 20. Create UserManagementLive.InvitationForm for sending invitations
  - Create form component at lib/rice_mill_web/live/user_management_live/invitation_form.ex
  - Add fields for email and role (operator or viewer only)
  - Prevent company admins from inviting super_admin or company_admin roles
  - Display invitation email preview
  - Call create_invitation/3 and send_invitation_email/1
  - Display success message with invitation sent confirmation
  - _Requirements: 7, 17_

- [x] 21. Create UserManagementLive.BulkImport for CSV user import
  - Create LiveView at lib/rice_mill_web/live/user_management_live/bulk_import.ex
  - Add file upload component for CSV files
  - Display CSV preview table after upload
  - Validate CSV data and highlight errors
  - Add "Import" button to confirm import
  - Call import_users_from_csv/3 function
  - Display import summary with success count and errors
  - _Requirements: 12, 17_

- [x] 22. Create UserInvitationLive.Accept for invitation acceptance
  - Create LiveView at lib/rice_mill_web/live/user_invitation_live/accept.ex
  - Load invitation by token from URL parameter
  - Display error if invitation is expired or invalid
  - Display registration form with email pre-filled (read-only)
  - Add fields for name, password, password_confirmation
  - Call accept_invitation/2 to create user account
  - Log user in automatically after successful registration
  - Redirect to dashboard with welcome message
  - _Requirements: 7, 17_

- [x] 23. Create AuditLogLive.Index for audit log viewing
  - Create LiveView at lib/rice_mill_web/live/admin/audit_log_live/index.ex
  - Display table of audit logs with user, action, resource, timestamp, IP address
  - Add filters for tenant, user, action type, and date range
  - Implement pagination for large result sets
  - Add "Export" button to download audit logs as CSV
  - Super admins see all logs, company admins see only their tenant logs
  - Implement handle_event for filter changes
  - _Requirements: 10, 17_

- [x] 24. Create TenantSettingsLive.Index for tenant configuration
  - Create LiveView at lib/rice_mill_web/live/tenant_settings_live/index.ex
  - Display tenant information (name, contact details)
  - Display tenant settings form (default_unit, timezone, date_format)
  - Add "Save" button to update tenant settings
  - Call update_tenant_settings/3 function
  - Display success message on save
  - Only accessible to company admins and super adminsKiro
  
  - _Requirements: 14, 17_

- [x] 25. Create UserProfileLive.Index for user profile management
  - Create LiveView at lib/rice_mill_web/live/user_profile_live/index.ex
  - Display current user information (email, name, contact_phone, role)
  - Add form to edit name and contact_phone
  - Add separate form to change password (current password, new password, confirmation)
  - Display user's own activity history
  - Call update_user/3 for profile updates
  - Call update_user_password/2 for password changes
  - Display success messages for updates
  - _Requirements: 13, 17_

- [x] 26. Update router with new admin and user management routes
  - Add /admin scope with RequireRole plug for super_admin
  - Add routes for TenantLive.Index, TenantLive.Show, AdminUserLive.Index, AuditLogLive.Index
  - Add /users/manage scope with RequireRole plug for company_admin
  - Add routes for UserManagementLive.Index, InvitationForm, BulkImport
  - Add /settings/tenant route with RequireRole plug for company_admin
  - Add /users/profile route for all authenticated users
  - Add /invitations/:token/accept public route for invitation acceptance
  - Update navigation menu to show admin links based on role
  - _Requirements: 1, 2, 4, 5, 7, 10, 13, 14, 15, 17_

- [x] 27. Update navigation menu with role-based links
  - Modify main navigation in lib/rice_mill_web/components/layouts/app.html.heex
  - Add "Admin" dropdown menu for super admins (Tenants, All Users, Audit Logs)
  - Add "Users" menu item for company admins (Manage Users)
  - Add "Settings" dropdown menu (Tenant Settings, My Profile)
  - Display current user role badge in header
  - Display tenant name in header for company admins
  - Hide/show menu items based on Authorization.can?/3 checks
  - _Requirements: 17_

- [x] 28. Create background job to expire old invitations
  - Create scheduled job module in lib/rice_mill/accounts/jobs/expire_invitations.ex
  - Query for invitations with status :pending and expires_at < now
  - Update status to :expired for matching invitations
  - Schedule job to run daily using Oban or similar job processor
  - Log expired invitation count
  - _Requirements: 7_

- [x] 29. Add session timeout and security enhancements
  - Update UserAuth to check session age and expire after 24 hours
  - Add function to list active sessions for a user
  - Add function to revoke specific sessions
  - Invalidate all sessions when password is changed (except current)
  - Add audit log entries for session events
  - _Requirements: 16_

- [x] 30. Create seed script for initial super admin
  - Create seed file in priv/repo/seeds.exs or separate admin seed file
  - Check if super admin exists, create if not
  - Use environment variables for email and password
  - Set role to :super_admin, status to :active
  - Log creation of super admin account
  - _Requirements: 3, 15_

- [ ]* 31. Write tests for Authorization module
  - Test can?/3 function for all role and action combinations
  - Test super_admin has access to all features
  - Test company_admin can only access own tenant
  - Test operator can manage inventory but not users
  - Test viewer has read-only access
  - Test cross-tenant access prevention
  - _Requirements: 6_

- [ ]* 32. Write tests for user management functions
  - Test create_user/2 with different roles
  - Test update_user/3 with authorization checks
  - Test deactivate_user/2 and activate_user/2
  - Test list_users_for_tenant/2 returns only tenant users
  - Test password reset functionality
  - Test audit log creation for user actions
  - _Requirements: 4, 5, 8, 9, 15_

- [ ]* 33. Write tests for tenant management functions
  - Test create_tenant_with_admin/3 creates both tenant and admin user
  - Test list_tenants_with_stats/0 includes user counts
  - Test get_tenant_activity_metrics/1 calculates correct metrics
  - Test tenant settings management
  - Test audit log creation for tenant actions
  - _Requirements: 1, 2, 3, 11, 14_

- [ ]* 34. Write tests for invitation workflow
  - Test create_invitation/3 generates secure token
  - Test invitation email delivery
  - Test accept_invitation/2 creates user account
  - Test invitation expiration
  - Test invalid token handling
  - _Requirements: 7_

- [ ]* 35. Write tests for CSV bulk import
  - Test validate_csv_import/1 with valid data
  - Test validation errors for invalid data
  - Test import_users_from_csv/3 creates users
  - Test transaction rollback on error
  - Test import summary generation
  - _Requirements: 12_

- [ ]* 36. Write integration tests for LiveViews
  - Test TenantLive.Index displays tenants for super admin
  - Test UserManagementLive.Index displays only tenant users for company admin
  - Test invitation form submission and email sending
  - Test bulk import upload and preview
  - Test audit log filtering
  - Test profile editing and password change
  - _Requirements: 17_

