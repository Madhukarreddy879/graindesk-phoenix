# Requirements Document

## Introduction

This document specifies the requirements for a Tenant and User Management System for the Rice Mill Inventory application. The system enables super administrators to onboard new tenants and create tenant admin accounts, while allowing company administrators to manage users within their own tenant. The feature includes role-based access control, user invitation workflows, audit logging, and activity monitoring to ensure secure and efficient multi-tenant operations.

## Glossary

- **Rice Mill System**: The inventory management application for tracking paddy stock
- **Tenant**: A company or organization using the system with isolated data
- **Super Admin**: System administrator with cross-tenant access to manage all tenants and users
- **Company Admin**: Tenant-level administrator who can manage users within their own tenant
- **Operator**: Standard user who can perform inventory operations but cannot manage users
- **Viewer**: Read-only user who can view reports but cannot modify data
- **User Invitation**: A secure token-based process for inviting new users to register
- **Audit Log**: A record of system actions performed by users for compliance and security
- **Phoenix Framework**: Elixir web framework used for building the application
- **PostgreSQL Database**: The relational database system used for data storage
- **Ecto**: Elixir database wrapper and query generator for PostgreSQL

## Requirements

### Requirement 1: Super Admin Tenant Management Dashboard

**User Story:** As a super admin, I want to view and manage all tenants in the system, so that I can oversee the entire multi-tenant application.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide a dashboard displaying all tenants with their name, slug, status, user count, and creation date
2. WHEN a super admin requests the tenant list, THE Rice Mill System SHALL display tenants sorted by creation date with most recent first
3. THE Rice Mill System SHALL display tenant status as active or inactive with visual indicators
4. THE Rice Mill System SHALL provide search functionality to filter tenants by name or slug
5. THE Rice Mill System SHALL display the total number of users associated with each tenant

### Requirement 2: Tenant Onboarding by Super Admin

**User Story:** As a super admin, I want to create new tenant accounts, so that I can onboard new rice mill companies to the system.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow super admins to create new tenants with name, slug, and status fields
2. WHEN a super admin creates a tenant, THE Rice Mill System SHALL validate that the slug is unique across all tenants
3. WHEN a super admin creates a tenant, THE Rice Mill System SHALL automatically set the status to active by default
4. THE Rice Mill System SHALL generate a URL-friendly slug from the tenant name if no slug is provided
5. THE Rice Mill System SHALL display a success message with the new tenant details after creation

### Requirement 3: Tenant Admin Account Creation by Super Admin

**User Story:** As a super admin, I want to create tenant admin accounts when onboarding a new tenant, so that the company can start managing their own users.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow super admins to create user accounts with email, password, role, and tenant assignment
2. WHEN a super admin creates a tenant admin account, THE Rice Mill System SHALL assign the role as company_admin
3. WHEN a super admin creates a tenant admin account, THE Rice Mill System SHALL associate the user with the specified tenant
4. THE Rice Mill System SHALL validate that the email address is unique across all users
5. THE Rice Mill System SHALL generate a secure temporary password and display it to the super admin for communication to the tenant admin

### Requirement 4: User Management Dashboard for Company Admins

**User Story:** As a company admin, I want to view and manage users in my company, so that I can control who has access to our inventory system.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide a user management dashboard for company admins showing all users in their tenant
2. WHEN a company admin requests the user list, THE Rice Mill System SHALL display only users belonging to their tenant
3. THE Rice Mill System SHALL display user email, role, status, and last login date for each user
4. THE Rice Mill System SHALL provide search functionality to filter users by email or role
5. THE Rice Mill System SHALL prevent company admins from viewing or managing users from other tenants

### Requirement 5: User Creation by Company Admins

**User Story:** As a company admin, I want to add new users to my company, so that my team members can access the inventory system.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow company admins to create user accounts with email, password, and role fields
2. WHEN a company admin creates a user, THE Rice Mill System SHALL automatically assign the user to the company admin's tenant
3. THE Rice Mill System SHALL allow company admins to assign roles of operator or viewer to new users
4. THE Rice Mill System SHALL prevent company admins from creating users with the company_admin or super_admin role
5. THE Rice Mill System SHALL validate that the email address is unique across all users

### Requirement 6: Role-Based Access Control

**User Story:** As a system user, I want my access permissions to match my assigned role, so that I can perform appropriate actions without compromising system security.

#### Acceptance Criteria

1. THE Rice Mill System SHALL enforce role-based permissions where super_admin can access all features across all tenants
2. THE Rice Mill System SHALL enforce role-based permissions where company_admin can manage users and access all inventory features within their tenant
3. THE Rice Mill System SHALL enforce role-based permissions where operator can create and edit products and stock-in entries within their tenant
4. THE Rice Mill System SHALL enforce role-based permissions where viewer can only view reports and data without modification capabilities
5. WHEN a user attempts an unauthorized action, THE Rice Mill System SHALL display an error message and prevent the action

### Requirement 7: User Invitation System

**User Story:** As a company admin, I want to invite users via email instead of creating passwords manually, so that users can set their own secure passwords.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow company admins to send user invitations by providing an email address and role
2. WHEN a company admin sends an invitation, THE Rice Mill System SHALL generate a unique secure token with 7-day expiration
3. WHEN a company admin sends an invitation, THE Rice Mill System SHALL send an email to the invited user with a registration link containing the token
4. WHEN an invited user clicks the registration link, THE Rice Mill System SHALL display a registration form pre-filled with the email address
5. WHEN an invited user completes registration, THE Rice Mill System SHALL create the user account and invalidate the invitation token

### Requirement 8: User Status Management

**User Story:** As a company admin, I want to activate or deactivate user accounts, so that I can control access without permanently deleting accounts.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow company admins to deactivate user accounts within their tenant
2. WHEN a user account is deactivated, THE Rice Mill System SHALL prevent that user from logging in
3. THE Rice Mill System SHALL allow company admins to reactivate previously deactivated user accounts
4. WHEN a user account is reactivated, THE Rice Mill System SHALL restore login access for that user
5. THE Rice Mill System SHALL display user status as active or inactive in the user management dashboard

### Requirement 9: Password Reset Functionality

**User Story:** As a company admin, I want to reset user passwords, so that I can help users who have forgotten their credentials.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow company admins to initiate password resets for users in their tenant
2. WHEN a company admin initiates a password reset, THE Rice Mill System SHALL generate a temporary password
3. WHEN a company admin initiates a password reset, THE Rice Mill System SHALL display the temporary password to the admin
4. THE Rice Mill System SHALL require users to change their password upon first login with a temporary password
5. THE Rice Mill System SHALL send a password reset email to the user if email functionality is configured

### Requirement 10: Audit Logging for User Actions

**User Story:** As a super admin or company admin, I want to view audit logs of user actions, so that I can track system usage and investigate security incidents.

#### Acceptance Criteria

1. THE Rice Mill System SHALL record audit log entries for user login, logout, user creation, user modification, and user deletion actions
2. WHEN an auditable action occurs, THE Rice Mill System SHALL store the user ID, action type, timestamp, IP address, and affected resource
3. THE Rice Mill System SHALL allow super admins to view audit logs for all tenants
4. THE Rice Mill System SHALL allow company admins to view audit logs only for their tenant
5. THE Rice Mill System SHALL provide filtering options for audit logs by date range, user, and action type

### Requirement 11: Tenant Activity Monitoring

**User Story:** As a super admin, I want to view activity metrics for each tenant, so that I can monitor system usage and identify inactive tenants.

#### Acceptance Criteria

1. THE Rice Mill System SHALL display activity metrics for each tenant including total users, active users, and last activity date
2. WHEN calculating active users, THE Rice Mill System SHALL count users who have logged in within the last 30 days
3. THE Rice Mill System SHALL display the date of the most recent stock-in entry for each tenant
4. THE Rice Mill System SHALL provide a visual indicator for tenants with no activity in the last 30 days
5. THE Rice Mill System SHALL allow super admins to sort tenants by activity metrics

### Requirement 12: Bulk User Import

**User Story:** As a company admin, I want to import multiple users at once from a CSV file, so that I can efficiently onboard large teams.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow company admins to upload a CSV file containing user data with columns for email, role, and name
2. WHEN a company admin uploads a CSV file, THE Rice Mill System SHALL validate each row for required fields and valid role values
3. WHEN a company admin uploads a CSV file, THE Rice Mill System SHALL display a preview of users to be created with validation errors highlighted
4. WHEN a company admin confirms the import, THE Rice Mill System SHALL create user accounts for all valid rows
5. THE Rice Mill System SHALL generate a summary report showing successful imports and any errors encountered

### Requirement 13: User Profile Management

**User Story:** As a user, I want to update my own profile information and password, so that I can maintain my account details.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow users to view and edit their own profile including name and contact information
2. THE Rice Mill System SHALL allow users to change their own password by providing the current password and new password
3. WHEN a user changes their password, THE Rice Mill System SHALL validate that the current password is correct
4. WHEN a user changes their password, THE Rice Mill System SHALL enforce password strength requirements of minimum 12 characters
5. THE Rice Mill System SHALL prevent users from modifying their email address or role

### Requirement 14: Tenant Settings Management

**User Story:** As a company admin, I want to configure tenant-specific settings, so that I can customize the system for my organization's needs.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide a settings page for company admins to configure tenant preferences
2. THE Rice Mill System SHALL allow company admins to update tenant name and contact information
3. THE Rice Mill System SHALL allow company admins to configure default values for stock-in forms such as default unit
4. THE Rice Mill System SHALL store tenant settings in the PostgreSQL Database associated with the tenant record
5. THE Rice Mill System SHALL apply tenant settings to all users within that tenant

### Requirement 15: Super Admin User Management

**User Story:** As a super admin, I want to manage users across all tenants, so that I can provide support and resolve access issues.

#### Acceptance Criteria

1. THE Rice Mill System SHALL allow super admins to view all users across all tenants
2. THE Rice Mill System SHALL allow super admins to edit user details including email, role, and tenant assignment
3. THE Rice Mill System SHALL allow super admins to transfer users from one tenant to another
4. THE Rice Mill System SHALL allow super admins to reset passwords for any user
5. THE Rice Mill System SHALL allow super admins to delete user accounts with confirmation prompt

### Requirement 16: Session Management and Security

**User Story:** As a system administrator, I want secure session management, so that user accounts are protected from unauthorized access.

#### Acceptance Criteria

1. THE Rice Mill System SHALL expire user sessions after 24 hours of inactivity
2. WHEN a user logs in from a new device or location, THE Rice Mill System SHALL create a new session token
3. THE Rice Mill System SHALL allow users to view active sessions and revoke access from specific devices
4. WHEN a user changes their password, THE Rice Mill System SHALL invalidate all existing sessions except the current one
5. THE Rice Mill System SHALL log all session creation and termination events in the audit log

### Requirement 17: User Interface for Tenant and User Management

**User Story:** As a super admin or company admin, I want an intuitive interface for managing tenants and users, so that I can efficiently perform administrative tasks.

#### Acceptance Criteria

1. THE Rice Mill System SHALL provide a navigation menu with links to tenant management and user management for authorized roles
2. THE Rice Mill System SHALL display management dashboards with tables showing relevant data and action buttons
3. THE Rice Mill System SHALL provide modal forms for creating and editing tenants and users
4. THE Rice Mill System SHALL display confirmation dialogs before destructive actions such as deletion or deactivation
5. THE Rice Mill System SHALL provide visual feedback for successful operations and validation errors

