defmodule RiceMillWeb.TenantSettingsLive.Index do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts

  @impl true
  def mount(_params, _session, socket) do
    current_user = socket.assigns.current_scope.user

    # Authorization check - only company admins and super admins can access
    if current_user.role in [:company_admin, :super_admin] do
      mount_authorized_user(socket, current_user)
    else
      {:ok,
       socket
       |> put_flash(:error, "You are not authorized to access tenant settings.")
       |> redirect(to: ~p"/")}
    end
  end

  defp mount_authorized_user(socket, current_user) do
    cond do
      current_user.role == :super_admin ->
        # For super_admin, they need to select a tenant from the admin panel
        # For now, redirect them to the tenant management page
        {:ok,
         socket
         |> put_flash(:info, "Please select a tenant from the admin panel to manage settings.")
         |> redirect(to: ~p"/admin/tenants")}

      is_nil(current_user.tenant_id) ->
        {:ok,
         socket
         |> put_flash(:error, "No tenant found for your account.")
         |> redirect(to: ~p"/")}

      true ->
        # Get tenant for the current user
        tenant = Accounts.get_tenant!(current_user.tenant_id)
        settings = Accounts.get_tenant_settings(tenant)
        changeset = build_settings_changeset(tenant, settings)

        {:ok,
         socket
         |> assign(:page_title, "Tenant Settings")
         |> assign(:tenant, tenant)
         |> assign(:settings, settings)
         |> assign(:form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate", %{"tenant" => tenant_params}, socket) do
    changeset =
      socket.assigns.tenant
      |> Accounts.change_tenant(tenant_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"tenant" => tenant_params}, socket) do
    current_user = socket.assigns.current_scope.user
    tenant = socket.assigns.tenant

    # Extract settings from the form parameters
    settings_attrs = %{
      "default_unit" => Map.get(tenant_params, "default_unit", "kg"),
      "timezone" => Map.get(tenant_params, "timezone", "UTC"),
      "date_format" => Map.get(tenant_params, "date_format", "YYYY-MM-DD")
    }

    # Update tenant settings first
    case Accounts.update_tenant_settings(tenant, current_user, settings_attrs) do
      {:ok, updated_tenant} ->
        # Then update tenant basic info
        basic_tenant_params =
          Map.take(tenant_params, ["name", "slug", "contact_email", "contact_phone", "active"])

        case Accounts.update_tenant(updated_tenant, current_user, basic_tenant_params) do
          {:ok, final_tenant} ->
            updated_settings = Accounts.get_tenant_settings(final_tenant)

            {:noreply,
             socket
             |> put_flash(:info, "Tenant settings updated successfully.")
             |> assign(:tenant, final_tenant)
             |> assign(:settings, updated_settings)
             |> assign(:form, to_form(build_settings_changeset(final_tenant, updated_settings)))}

          {:error, :unauthorized} ->
            {:noreply,
             put_flash(socket, :error, "You are not authorized to update tenant information.")}

          {:error, changeset} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to update tenant information.")
             |> assign(:form, to_form(changeset))}
        end

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to update tenant settings.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to update tenant settings.")}
    end
  end

  defp build_settings_changeset(tenant, settings) do
    # Build a changeset for the tenant fields with current values
    tenant_changeset =
      Accounts.change_tenant(tenant, %{
        "name" => tenant.name,
        "slug" => tenant.slug,
        "active" => tenant.active,
        "contact_email" => tenant.contact_email || "",
        "contact_phone" => tenant.contact_phone || ""
      })

    # Add settings as virtual fields to the changeset
    Ecto.Changeset.cast(
      tenant_changeset,
      %{
        "default_unit" => settings["default_unit"] || "kg",
        "timezone" => settings["timezone"] || "UTC",
        "date_format" => settings["date_format"] || "YYYY-MM-DD"
      },
      [:default_unit, :timezone, :date_format]
    )
  end
end
