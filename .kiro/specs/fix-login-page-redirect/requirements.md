# Requirements Document

## Introduction

This feature addresses a critical bug preventing super admin users from accessing the admin dashboard after successful login. The error occurs due to incorrect usage of the `Layouts.app` component in the dashboard LiveView template, where the `@inner_content` assign is not being passed correctly, resulting in a KeyError.

## Glossary

- **System**: The Rice Mill web application
- **Dashboard_LiveView**: The admin dashboard LiveView module located at `RiceMillWeb.Admin.DashboardLive.Index`
- **Layout_Component**: The `Layouts.app` component defined in `lib/rice_mill_web/components/layouts/app.html.heex`
- **Super_Admin**: A user with the `:super_admin` role who has access to the admin dashboard
- **Inner_Content**: The slot content that should be rendered inside the layout component

## Requirements

### Requirement 1

**User Story:** As a super admin, I want to successfully access the admin dashboard after logging in, so that I can view system statistics and manage tenants.

#### Acceptance Criteria

1. WHEN a Super_Admin navigates to `/admin/dashboard`, THE System SHALL render the dashboard page without KeyError exceptions
2. WHEN the Dashboard_LiveView renders, THE System SHALL correctly pass inner content to the Layout_Component using Phoenix LiveView slot conventions
3. WHEN the dashboard loads, THE System SHALL display all dashboard statistics including total tenants, active tenants, inactive tenants, and total users
4. WHEN the dashboard renders, THE System SHALL display the quick actions section with links to manage tenants, create tenant, manage users, and audit logs
5. WHEN the dashboard renders, THE System SHALL display the recent tenants list with proper tenant information

### Requirement 2

**User Story:** As a developer, I want the layout component to follow Phoenix LiveView best practices, so that the application is maintainable and follows framework conventions.

#### Acceptance Criteria

1. THE Dashboard_LiveView template SHALL use the `<:inner_block>` slot syntax when wrapping content with the Layout_Component
2. THE Layout_Component SHALL render the `@inner_block` slot content in the main content area
3. THE System SHALL pass all required assigns (`flash`, `current_scope`) to the Layout_Component
4. THE Dashboard_LiveView template SHALL NOT use the deprecated component wrapper syntax that causes KeyError exceptions
5. THE System SHALL maintain backward compatibility with other LiveViews that use the Layout_Component

### Requirement 3

**User Story:** As a super admin, I want the dashboard to display accurate real-time statistics, so that I can monitor the system effectively.

#### Acceptance Criteria

1. WHEN the Dashboard_LiveView mounts, THE System SHALL fetch current statistics from the database
2. THE System SHALL display the count of total tenants with accurate data
3. THE System SHALL display the count of active tenants with accurate data
4. THE System SHALL display the count of inactive tenants with accurate data
5. THE System SHALL display the count of total users across all tenants with accurate data
