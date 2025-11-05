# Implementation Plan

- [x] 1. Fix authentication redirect logic
  - Modify `signed_in_path/1` function in `lib/rice_mill_web/user_auth.ex` to implement role-based routing
  - Add pattern matching for `:super_admin` role to redirect to `/admin/tenants`
  - Add pattern matching for `:company_admin`, `:operator`, and `:viewer` roles to redirect to `/products`
  - Keep fallback pattern for edge cases
  - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Enhance TenantLive.Index module with search state tracking
  - Add `search_query` assign to track current search term in `mount/3`
  - Add `tenants_empty?` assign to track empty state in `mount/3`
  - Update `handle_event("search")` to set both new assigns
  - Implement `handle_event("clear_search")` to reset search and reload all tenants
  - _Requirements: 4.1, 4.3, 4.4_

- [x] 3. Create modern search interface component
  - Replace basic search form with modern styled input container
  - Add search icon indicator to the left of input field
  - Add clear button that appears when search query is not empty
  - Style search button with modern indigo theme
  - Ensure search input has proper focus states and accessibility
  - _Requirements: 4.1, 4.2, 4.5_

- [x] 4. Implement desktop card-based layout
  - Create responsive grid container with 1/2/3 column layout (md/lg/xl breakpoints)
  - Design tenant card component with white background and shadow
  - Add card header with tenant name and status badge
  - Add card body with slug, user count, and last activity (with icons)
  - Add card footer with action buttons in horizontal layout
  - Apply hover effects and transitions to cards
  - Hide desktop layout on mobile with `hidden md:block`
  - _Requirements: 2.1, 2.3, 2.4, 2.5, 3.1, 3.2, 3.3, 3.4, 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 5. Implement mobile stacked layout
  - Create mobile-specific card layout with full width
  - Stack action buttons vertically for better touch targets
  - Adjust font sizes for mobile readability
  - Ensure minimum touch target size of 44x44px for buttons
  - Show mobile layout only on small screens with `block md:hidden`
  - _Requirements: 2.2, 6.1, 6.2, 6.3, 6.4, 6.5_

- [x] 6. Add empty state messaging
  - Create empty state component with icon and message
  - Display "No tenants yet" message when no tenants exist and search is empty
  - Display "No tenants found matching '{query}'" when search returns no results
  - Add helpful suggestion text below empty state message
  - Conditionally render empty state based on `tenants_empty?` assign
  - _Requirements: 3.5, 4.4_

- [x] 7. Modernize header and create tenant button
  - Update page title with larger font and modern styling
  - Style "Create Tenant" button with indigo theme and hover effects
  - Add proper spacing and alignment between title and button
  - Ensure button is responsive on mobile devices
  - _Requirements: 2.3, 2.4, 5.1, 5.4_

- [ ]* 8. Add tests for authentication redirect logic
  - Write test for super_admin redirect to `/admin/tenants`
  - Write test for company_admin redirect to `/products`
  - Write test for operator redirect to `/products`
  - Write test for viewer redirect to `/products`
  - Write test for nil user fallback to `/`
  - _Requirements: 1.1, 1.2, 1.3_

- [ ]* 9. Add tests for tenant list interface
  - Write test for mounting and displaying tenants
  - Write test for search functionality
  - Write test for clear search functionality
  - Write test for empty state when no tenants exist
  - Write test for empty state when search returns no results
  - Write test for activate/deactivate actions
  - _Requirements: 2.1, 4.1, 4.3, 4.4, 3.5_
