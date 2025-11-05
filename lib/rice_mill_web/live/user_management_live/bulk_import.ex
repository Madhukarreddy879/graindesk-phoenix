defmodule RiceMillWeb.UserManagementLive.BulkImport do
  use RiceMillWeb, :live_view

  alias RiceMill.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Bulk Import Users")
     |> assign(:uploaded_files, [])
     |> assign(:csv_preview, nil)
     |> assign(:validation_result, nil)
     |> assign(:import_summary, nil)
     |> allow_upload(:csv_file,
       accept: ~w(.csv text/csv),
       max_entries: 1,
       max_file_size: 5_000_000
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :csv_file, ref)}
  end

  @impl true
  def handle_event("preview", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        {:ok, File.read!(path)}
      end)

    case uploaded_files do
      [csv_content] ->
        current_user = socket.assigns.current_scope.user
        tenant_id = current_user.tenant_id

        case parse_and_validate_csv(csv_content, tenant_id, current_user) do
          {:ok, validation_result, preview_data} ->
            {:noreply,
             socket
             |> assign(:csv_preview, preview_data)
             |> assign(:validation_result, validation_result)
             |> put_flash(:info, "CSV file validated. Review the preview below.")}

          {:error, :empty_csv} ->
            {:noreply,
             socket
             |> put_flash(:error, "The CSV file is empty")
             |> assign(:csv_preview, nil)
             |> assign(:validation_result, nil)}

          {:error, {:missing_headers, headers}} ->
            {:noreply,
             socket
             |> put_flash(
               :error,
               "Missing required CSV headers: #{Enum.join(headers, ", ")}. Required: email, role"
             )
             |> assign(:csv_preview, nil)
             |> assign(:validation_result, nil)}

          {:error, :invalid_csv_format} ->
            {:noreply,
             socket
             |> put_flash(:error, "Invalid CSV format. Please check your file.")
             |> assign(:csv_preview, nil)
             |> assign(:validation_result, nil)}

          {:error, reason} ->
            {:noreply,
             socket
             |> put_flash(:error, "Failed to parse CSV: #{inspect(reason)}")
             |> assign(:csv_preview, nil)
             |> assign(:validation_result, nil)}
        end

      [] ->
        {:noreply,
         socket
         |> put_flash(:error, "Please upload a CSV file first")
         |> assign(:csv_preview, nil)
         |> assign(:validation_result, nil)}
    end
  end

  @impl true
  def handle_event("import", _params, socket) do
    validation_result = socket.assigns.validation_result

    if validation_result && length(validation_result.valid_rows) > 0 do
      current_user = socket.assigns.current_scope.user
      tenant_id = current_user.tenant_id

      # Create CSV content from validation result
      csv_content = build_csv_from_validation_result(validation_result)

      case Accounts.import_users_from_csv(csv_content, tenant_id, current_user) do
        {:ok, summary} ->
          {:noreply,
           socket
           |> assign(:import_summary, summary)
           |> assign(:csv_preview, nil)
           |> assign(:validation_result, nil)
           |> put_flash(
             :info,
             "Import completed! #{summary.successful} users created successfully."
           )}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(:error, "Import failed: #{inspect(reason)}")}
      end
    else
      {:noreply,
       socket
       |> put_flash(
         :error,
         "No valid rows to import. Please upload and preview a CSV file first."
       )}
    end
  end

  @impl true
  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:csv_preview, nil)
     |> assign(:validation_result, nil)
     |> assign(:import_summary, nil)
     |> put_flash(:info, "Ready for new import")}
  end

  defp parse_and_validate_csv(csv_content, tenant_id, current_user) do
    with {:ok, parsed_data} <- parse_csv_content(csv_content),
         {:ok, validation_result} <-
           Accounts.validate_csv_import(parsed_data, tenant_id, current_user) do
      # Create preview data (limit to first 20 rows for display)
      preview_data = %{
        valid_rows: Enum.take(validation_result.valid_rows, 20),
        invalid_rows: validation_result.invalid_rows,
        total_valid: length(validation_result.valid_rows),
        total_invalid: length(validation_result.invalid_rows),
        showing_preview: min(length(validation_result.valid_rows), 20)
      }

      {:ok, validation_result, preview_data}
    end
  end

  defp parse_csv_content(csv_content) when is_binary(csv_content) do
    try do
      csv_module = NimbleCSV.RFC4180
      parsed_rows = csv_module.parse_string(csv_content, skip_headers: false)

      case parsed_rows do
        [] ->
          {:error, :empty_csv}

        [headers | data_rows] ->
          headers = Enum.map(headers, &String.trim/1)

          with :ok <- validate_csv_headers(headers) do
            data_maps =
              Enum.map(data_rows, fn row ->
                Enum.zip(headers, Enum.map(row, &String.trim/1))
                |> Map.new()
              end)

            {:ok, data_maps}
          end
      end
    rescue
      _ -> {:error, :invalid_csv_format}
    end
  end

  defp validate_csv_headers(headers) do
    required_headers = ["email", "role"]
    missing_headers = required_headers -- headers

    if Enum.empty?(missing_headers) do
      :ok
    else
      {:error, {:missing_headers, missing_headers}}
    end
  end

  defp build_csv_from_validation_result(validation_result) do
    # Rebuild CSV content from valid rows for import
    headers = ["email", "role", "name", "contact_phone"]

    csv_rows =
      validation_result.valid_rows
      |> Enum.map(fn row ->
        [
          row.email,
          Atom.to_string(row.role),
          row.name || "",
          row.contact_phone || ""
        ]
      end)

    csv_module = NimbleCSV.RFC4180

    csv_module.dump_to_iodata([headers | csv_rows])
    |> IO.iodata_to_binary()
  end

  defp error_to_string(:too_large), do: "File is too large (max 5MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted (CSV only)"
  defp error_to_string(:too_many_files), do: "Too many files (max 1)"
  defp error_to_string(error), do: "Upload error: #{inspect(error)}"
end
