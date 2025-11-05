# Design Document

## Overview

This design addresses two critical issues in the superadmin experience:
1. **Navigation Logic**: Fix the post-login redirect to route users to their appropriate dashboard based on role
2. **UI Modernization**: Transform the tenant list from a basic table to a modern, responsive interface with card-based layouts, improved visual hierarchy, and delightful micro-interactions

The solution leverages Phoenix LiveView's reactive capabilities, Tailwind CSS for modern styling, and follows accessibility best practices.

## Architecture

### Component Structure

```
UserAuth Module (lib/rice_mill_web/user_auth.ex)
├── signed_in_path/1 - Enhanced with role-based routing logic
└── log_in_user/3 - Uses signed_in_path for redirect

Admin.TenantLive.Index (lib/rice_mill_web/live/admin/tenant_live/index.ex)
├── mount/3 - Initialize state with empty state tracking
├── handle_event("search", ...) - Enhanced with empty state handling
└── handle_event("clear_search", ...) - New: Clear search and reset

Template (lib/rice_mill_web/live/admin/tenant_live/index.html.heex)
├── Search Section - Modern input with icons and clear button
├── Desktop View - Card-based grid layout (hidden on mobile)
├── Mobile View - Stacked card layout (hidden on desktop)
└── Empty State - Contextual messaging for no results
```

### Data Flow

1. **Authentication Flow**:
   - User logs in → `log_in_user/3` called
   - `signed_in_path/1` evaluates user role
   - Redirect to role-appropriate dashboard

2. **Search Flow**:
   - User types → form submission → `handle_event("search")`
   - Query tenants → Update stream with results
   - Track empty state → Render appropriate UI

3. **Responsive Layout Flow**:
   - CSS media queries determine viewport size
   - Tailwind responsive classes show/hide layouts
   - Touch-friendly sizing on mobile

## Components and Interfaces

### 1. Enhanced UserAuth Module

**Location**: `lib/rice_mill_web/user_auth.ex`

**Modified Function**: `signed_in_path/1`

```elixir
def signed_in_path(%Plug.Conn{assigns: %{current_scope: %Scope{user: %Accounts.User{role: role}}}}) do
  case role do
    :super_admin -> ~p"/admin/tenants"
    :company_admin -> ~p"/products"
    :operator -> ~p"/products"
    :viewer -> ~p"/products"
    _ -> ~p"/"
  end
end

def signed_in_path(_), do: ~p"/"
```

**Rationale**: 
- Super admins manage tenants as their primary function
- Company admins, operators, and viewers work with inventory
- Fallback to home for edge cases

### 2. Enhanced TenantLive.Index Module

**Location**: `lib/rice_mill_web/live/admin/tenant_live/index.ex`

**New Assigns**:
- `search_query` - Track current search term for display
- `tenants_empty?` - Boolean flag for empty state rendering

**Modified Functions**:

```elixir
def mount(_params, _session, socket) do
  tenants = list_tenants()
  
  socket =
    socket
    |> assign(:search_query, "")
    |> assign(:tenants_empty?, tenants == [])
    |> stream_configure(:tenants, dom_id: fn %{tenant: tenant} -> "tenant-#{tenant.id}" end)
    |> stream(:tenants, tenants)

  {:ok, socket}
end

def handle_event("search", %{"query" => query}, socket) do
  tenants = search_tenants(query)
  
  {:noreply,
   socket
   |> assign(:search_query, query)
   |> assign(:tenants_empty?, tenants == [])
   |> stream(:tenants, tenants, reset: true)}
end

def handle_event("clear_search", _params, socket) do
  tenants = list_tenants()
  
  {:noreply,
   socket
   |> assign(:search_query, "")
   |> assign(:tenants_empty?, tenants == [])
   |> stream(:tenants, tenants, reset: true)}
end
```

### 3. Modernized Template Design

**Location**: `lib/rice_mill_web/live/admin/tenant_live/index.html.heex`

#### Layout Structure

```
Container (max-w-7xl, responsive padding)
├── Header Section
│   ├── Title with gradient text
│   └── Create Tenant button (primary CTA)
├── Search Section
│   ├── Search input with icon
│   ├── Search button
│   └── Clear button (conditional)
├── Desktop Layout (hidden md:block)
│   ├── Grid of cards (3 columns on xl, 2 on lg, 1 on md)
│   └── Each card contains tenant info + actions
├── Mobile Layout (block md:hidden)
│   ├── Stacked cards
│   └── Vertical action buttons
└── Empty State (conditional)
    ├── Icon indicator
    ├── Message
    └── Suggestion text
```

#### Card Design Pattern

Each tenant card includes:
- **Header**: Tenant name (large, bold) + status badge
- **Body**: 
  - Slug with icon
  - User count with icon
  - Last activity with icon
- **Footer**: Action buttons in horizontal layout (desktop) or vertical (mobile)

#### Color Scheme

- **Primary Actions**: Indigo/Blue (`bg-indigo-600`, `hover:bg-indigo-700`)
- **Success States**: Green (`bg-green-100`, `text-green-800`)
- **Warning States**: Red (`bg-red-100`, `text-red-800`)
- **Neutral Elements**: Gray scale (`gray-50` to `gray-900`)
- **Backgrounds**: White cards on `gray-50` background

#### Micro-interactions

- Button hover: Color transition (150ms ease)
- Card hover: Subtle shadow elevation
- Search input focus: Ring effect with brand color
- Status badge: Pulse animation for active state (optional)

## Data Models

No changes to existing data models. The design works with existing:
- `Tenant` schema
- `TenantStats` structure (tenant + user_count + last_activity)

## Error Handling

### Search Errors

If `search_tenants/1` raises an exception:
- Catch in `handle_event("search")`
- Display flash error message
- Maintain current tenant list
- Log error for debugging

### Empty States

- **No tenants exist**: "No tenants yet. Create your first tenant to get started."
- **Search returns no results**: "No tenants found matching '{query}'. Try a different search term."
- **All tenants filtered out**: Same as search no results

### Responsive Breakpoints

- **Mobile**: < 768px (sm, base)
- **Tablet**: 768px - 1024px (md)
- **Desktop**: 1024px - 1280px (lg)
- **Large Desktop**: > 1280px (xl)

## Testing Strategy

### Unit Tests

**File**: `test/rice_mill_web/user_auth_test.exs`

Test cases:
1. `signed_in_path/1` returns `/admin/tenants` for super_admin
2. `signed_in_path/1` returns `/products` for company_admin
3. `signed_in_path/1` returns `/products` for operator
4. `signed_in_path/1` returns `/products` for viewer
5. `signed_in_path/1` returns `/` for nil user

### Integration Tests

**File**: `test/rice_mill_web/live/admin/tenant_live_test.exs`

Test cases:
1. Mount displays all tenants in card layout
2. Search filters tenants correctly
3. Clear search resets to all tenants
4. Empty state displays when no tenants exist
5. Empty state displays when search returns no results
6. Action buttons (activate/deactivate) work correctly
7. Navigation to view/edit pages works

### Visual Regression Tests

Manual testing checklist:
- [ ] Cards display correctly on desktop (3 columns on xl)
- [ ] Cards display correctly on tablet (2 columns)
- [ ] Cards stack correctly on mobile
- [ ] Action buttons are touch-friendly on mobile (44x44px minimum)
- [ ] Search input is accessible and functional
- [ ] Hover states work on all interactive elements
- [ ] Status badges are visually distinct
- [ ] Empty states display appropriate messages

### Accessibility Tests

- [ ] All interactive elements are keyboard accessible
- [ ] Focus indicators are visible
- [ ] Color contrast meets WCAG AA standards (4.5:1 for text)
- [ ] Screen reader announces status changes
- [ ] Form labels are properly associated

## Implementation Notes

### Tailwind CSS Classes

Key utility patterns:
- Responsive visibility: `hidden md:block`, `block md:hidden`
- Grid layouts: `grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-6`
- Card styling: `bg-white rounded-lg shadow-sm hover:shadow-md transition-shadow`
- Button states: `hover:bg-indigo-700 focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500`

### Phoenix LiveView Patterns

- Use `stream/4` with `reset: true` for search results
- Track empty state with separate assign (streams aren't enumerable)
- Use `phx-submit` for search form
- Use `phx-click` for clear button
- Maintain search query in assigns for display

### Performance Considerations

- Cards render efficiently with LiveView streams
- CSS transitions are GPU-accelerated (transform, opacity)
- No JavaScript required for responsive layout (pure CSS)
- Search debouncing not needed (form submission pattern)

## Design Decisions

### Why Card Layout Over Table?

- **Better mobile experience**: Cards stack naturally, tables require horizontal scroll
- **More visual space**: Can include icons, badges, and better typography
- **Modern aesthetic**: Cards are contemporary UI pattern
- **Flexibility**: Easier to add new information without cramping

### Why Role-Based Redirects?

- **User expectations**: Users expect to land on their primary workspace
- **Efficiency**: Reduces clicks to reach common tasks
- **Role clarity**: Reinforces what each role's primary function is

### Why Separate Mobile/Desktop Layouts?

- **Optimal experience**: Each layout optimized for its context
- **Maintainability**: Easier to modify layouts independently
- **Performance**: No complex responsive table hacks

### Why Empty State Messaging?

- **User guidance**: Helps users understand what to do next
- **Reduces confusion**: Clear feedback when no results found
- **Professional polish**: Shows attention to detail
