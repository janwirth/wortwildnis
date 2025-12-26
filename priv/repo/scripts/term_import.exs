# Script to import terms from EdgeDB to PostgreSQL
# Usage: mix run priv/repo/scripts/term_import.exs [limit]
# Example: mix run priv/repo/scripts/term_import.exs 100

alias Wortwildnis.Dictionary.Term
require Ash.Query
import Ash.Expr

# Decode HTML entities in text
decode_html_entities = fn text ->
  if is_nil(text) or text == "" do
    text
  else
    text
    |> HtmlEntities.decode()
  end
end

limit = case System.argv() do
  [limit_str] -> String.to_integer(limit_str)
  [] -> 10
  _ ->
    IO.puts("Usage: mix run priv/repo/scripts/term_import.exs [limit]")
    System.halt(1)
end

IO.puts("\n=== Importing #{limit} terms from EdgeDB ===\n")

# Query EdgeDB for terms
query_edgedb_terms = fn client, limit ->
  try do
    query = "select Term {term, description, example} limit #{limit}"
    result = Gel.query!(client, query)
    # Convert Gel.Set to list
    items = Enum.to_list(result)
    {:ok, items}
  rescue
    e -> {:error, e}
  end
end

# Prep a single item: decode HTML entities and format
prep_item = fn item ->
  # Gel.Object implements Access protocol, access fields with bracket notation
  name_raw = item["term"] || item[:term]
  description_raw = item["description"] || item[:description]
  example_raw = item["example"] || item[:example]

  # Decode HTML entities
  name = decode_html_entities.(name_raw)
  description = decode_html_entities.(description_raw)
  example = decode_html_entities.(example_raw)

  %{
    name: name,
    description: description,
    example: example,
    valid?: not is_nil(name) and not is_nil(description) and name != "" and description != ""
  }
end

verify_import = fn items ->
  items
  |> Enum.reduce_while(nil, fn item, _acc ->
    # IO.inspect(item[:description])
    result = Wortwildnis.Dictionary.Term
      |> Ash.Query.for_read(:by_content, description: item[:description]|> HtmlEntities.decode(), name: item[:term]|> HtmlEntities.decode())
      |> Ash.Query.limit(1)
      |> Ash.read!()
    case result do
      [one] ->
        # IO.inspect(item)
        {:cont, nil}
      [] ->
        # Prep and insert the first missing term
        prepped = prep_item.(item)
        if prepped.valid? do
          term_input = Map.delete(prepped, :valid?)
          IO.puts("\n=== Inserting missing term: #{term_input.name} ===")
          created_term = Ash.create!(Term, term_input, action: :create)
          IO.inspect(created_term, label: "Inserted term")
          {:cont, created_term}
        else
          IO.puts("\n⚠️  Invalid term (skipping): #{inspect(prepped)}")
          {:halt, nil}
        end
    end
  end)
end

# Process the import
process_import = fn items ->
  return_records? = true  # Enable to get actual count of created records
  return_errors? = true

  # Convert EdgeDB results to Ash input format and filter out invalid entries
  {term_inputs, invalid_terms} =
    items
    |> Enum.map(&prep_item.(&1))
    |> Enum.split_with(fn term -> term.valid? end)

  # Remove the valid? flag and keep only valid terms
  term_inputs = Enum.map(term_inputs, fn term -> Map.delete(term, :valid?) end)
  invalid_count = length(invalid_terms)

  # Skip pre-filtering - let the database unique constraint handle duplicates
  # This is faster and simpler, and the DB will reject duplicates automatically

  # Bulk create all valid terms - database will handle uniqueness
  # Use transaction: false so each insert is independent
  # This prevents one error from rolling back an entire batch
  # Set stop_on_error?: false to continue processing even when errors occur
  bulk_opts = [
    return_records?: return_records?,
    return_errors?: return_errors?,
    stop_on_error?: false,
    transaction: false
  ]

  bulk_result = Ash.bulk_create(term_inputs, Term, :bulk_import, bulk_opts)

  # Debug: Log bulk_result structure
  IO.puts("\n[DEBUG] Bulk result structure:")
  IO.inspect(bulk_result, label: "bulk_result", limit: :infinity)

  # Debug: Check all keys in bulk_result
  IO.puts("\n[DEBUG] Bulk result keys: #{inspect(Map.keys(bulk_result))}")

  # Check for error_index or similar fields that map errors to input items
  error_index = Map.get(bulk_result, :error_index)
  if error_index do
    IO.puts("\n[DEBUG] Bulk result has error_index field:")
    IO.inspect(error_index, label: "error_index", limit: :infinity)
  end

  # Extract errors from bulk_result
  # Ash.BulkResult is a struct, access fields directly
  # Handle case where errors might be nil or not present
  errors =
    if return_errors? do
      case bulk_result do
        %{errors: errs} when is_list(errs) -> errs
        %{errors: errs} when is_nil(errs) -> []
        _ -> []
      end
    else
      []
    end

  # Debug: Log errors
  IO.puts("\n[DEBUG] Total errors: #{length(errors)}")
  if length(errors) > 0 do
    IO.puts("[DEBUG] First error:")
    IO.inspect(Enum.at(errors, 0), label: "first_error", limit: :infinity)
  end

  # Get successfully created records
  created_records =
    case bulk_result do
      %{records: records} when is_list(records) -> records
      _ -> []
    end

  created_names = Enum.map(created_records, & &1.name) |> MapSet.new()

  # Helper function to extract name from error
  # Ash errors have field, value, and message, but not changeset directly
  # For InvalidAttribute errors, if field is :name, use the value
  # For Invalid errors (which wrap InvalidAttribute), check if changeset exists
  extract_name_from_error = fn error ->
    case error do
      # Direct InvalidAttribute error - check if field is :name and use value
      %Ash.Error.Changes.InvalidAttribute{field: :name, value: value} when not is_nil(value) ->
        value

      # InvalidAttribute error wrapped in Invalid
      %Ash.Error.Invalid{errors: errors_list, changeset: changeset} when is_list(errors_list) ->
        # First try to get name from InvalidAttribute with field :name
        name_from_attr = Enum.find_value(errors_list, fn err ->
          case err do
            %Ash.Error.Changes.InvalidAttribute{field: :name, value: value} when not is_nil(value) ->
              value
            _ ->
              nil
          end
        end)

        if name_from_attr do
          name_from_attr
        else
          # Fallback: try to get name from changeset if available
          case changeset do
            %Ash.Changeset{attributes: %{name: name}} when not is_nil(name) ->
              name
            %Ash.Changeset{params: %{"name" => name}} when not is_nil(name) ->
              name
            %Ash.Changeset{params: %{name: name}} when not is_nil(name) ->
              name
            _ ->
              nil
          end
        end

      # Invalid error without nested errors - check changeset
      %Ash.Error.Invalid{changeset: changeset} ->
        case changeset do
          %Ash.Changeset{attributes: %{name: name}} when not is_nil(name) ->
            name
          %Ash.Changeset{params: %{"name" => name}} when not is_nil(name) ->
            name
          %Ash.Changeset{params: %{name: name}} when not is_nil(name) ->
            name
          _ ->
            nil
        end

      _ ->
        nil
    end
  end

  # Count unique constraint errors as duplicates (handled by DB constraint)
  # Errors can be either direct InvalidAttribute or wrapped in Invalid
  # Also extract names from duplicate errors for comparison
  {unique_constraint_errors, duplicate_names} =
    errors
    |> Enum.reduce({[], MapSet.new()}, fn error, {acc_errors, acc_names} ->
      is_unique_error = case error do
        # Direct InvalidAttribute error
        %Ash.Error.Changes.InvalidAttribute{private_vars: private_vars} ->
          Keyword.get(private_vars, :constraint_type) == :unique
        # Wrapped in Invalid error
        %Ash.Error.Invalid{errors: errors_list} ->
          Enum.any?(errors_list, fn err_item ->
            case err_item do
              %Ash.Error.Changes.InvalidAttribute{private_vars: private_vars} ->
                Keyword.get(private_vars, :constraint_type) == :unique
              _ ->
                false
            end
          end)
        _ ->
          false
      end

      if is_unique_error do
        # Try to extract the name from the error
        name = extract_name_from_error.(error)
        name_set = if name, do: MapSet.put(acc_names, name), else: acc_names
        {[error | acc_errors], name_set}
      else
        {acc_errors, acc_names}
      end
    end)

  # Debug: Log counts
  IO.puts("\n[DEBUG] Created records count: #{length(created_records)}")
  IO.puts("[DEBUG] Created names count: #{MapSet.size(created_names)}")
  IO.puts("[DEBUG] Duplicate errors count: #{length(unique_constraint_errors)}")
  IO.puts("[DEBUG] Duplicate names count: #{MapSet.size(duplicate_names)}")
  IO.puts("[DEBUG] Total input terms: #{length(term_inputs)}")

  # Build a map of input index to error (if error_index is available)
  error_by_index = if error_index && is_map(error_index) do
    error_index
  else
    # Fallback: try to match errors to inputs by name
    errors
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {error, idx}, acc ->
      name = extract_name_from_error.(error)
      if name do
        # Find the index of the input with this name
        input_idx = Enum.find_index(term_inputs, & &1.name == name)
        if input_idx, do: Map.put(acc, input_idx, error), else: acc
      else
        acc
      end
    end)
  end

  # Find the first item that was not skipped as duplicate but also not inserted
  first_missing_item_with_index =
    term_inputs
    |> Enum.with_index()
    |> Enum.find(fn {term_input, idx} ->
      name = term_input.name
      not MapSet.member?(created_names, name) and not MapSet.member?(duplicate_names, name)
    end)

  if first_missing_item_with_index do
    {first_missing_item, missing_idx} = first_missing_item_with_index
    IO.puts("\n[DEBUG] First item that was NOT skipped as duplicate but also NOT inserted:")
    IO.inspect(first_missing_item, label: "missing_item", limit: :infinity)
    IO.puts("[DEBUG] Item name: #{inspect(first_missing_item.name)}")
    IO.puts("[DEBUG] Item index: #{missing_idx}")

    # Try to find the corresponding error for this item
    corresponding_error = Map.get(error_by_index, missing_idx)

    if corresponding_error do
      IO.puts("\n[DEBUG] Corresponding error for this item (found via index #{missing_idx}):")
      IO.inspect(corresponding_error, label: "corresponding_error", limit: :infinity)

      # Try to extract more details from the error
      case corresponding_error do
        %Ash.Error.Changes.InvalidAttribute{} = err ->
          IO.puts("[DEBUG] Error type: InvalidAttribute")
          IO.puts("[DEBUG] Error field: #{inspect(err.field)}")
          IO.puts("[DEBUG] Error message: #{inspect(err.message)}")
          IO.puts("[DEBUG] Error value: #{inspect(err.value)}")
        %Ash.Error.Invalid{} = err ->
          IO.puts("[DEBUG] Error type: Invalid")
          if Map.has_key?(err, :fields) do
            IO.puts("[DEBUG] Error fields: #{inspect(err.fields)}")
          end
          if Map.has_key?(err, :errors) && is_list(err.errors) do
            IO.puts("[DEBUG] Nested errors count: #{length(err.errors)}")
            if length(err.errors) > 0 do
              IO.puts("[DEBUG] First nested error:")
              IO.inspect(Enum.at(err.errors, 0), label: "first_nested_error", limit: :infinity)
            end
          end
        _ ->
          IO.puts("[DEBUG] Error type: #{inspect(corresponding_error.__struct__)}")
          IO.puts("[DEBUG] Full error structure:")
          IO.inspect(corresponding_error, label: "full_error", limit: :infinity)
      end
    else
      IO.puts("\n[DEBUG] No corresponding error found for this item (index #{missing_idx})")
      IO.puts("[DEBUG] This suggests the item was silently skipped or failed without an error")
      IO.puts("[DEBUG] Available error indices: #{inspect(Map.keys(error_by_index))}")
    end
  else
    IO.puts("\n[DEBUG] No missing items found - all items were either created or marked as duplicates")
  end

  # Other errors (not unique constraint violations)
  other_errors = errors -- unique_constraint_errors

  # Calculate counts
  duplicate_count = length(unique_constraint_errors)
  other_error_count = length(other_errors)
  valid_input_count = length(term_inputs)

  # Get actual created count from bulk_result records
  # This is the true count of what was actually inserted
  actual_created_count =
    case bulk_result do
      %{records: records} when is_list(records) ->
        length(records)
      %{records_count: count} when is_integer(count) ->
        count
      _ ->
        # Fallback calculation if records not available
        # (though this should not happen with return_records?: true)
        valid_input_count - duplicate_count - other_error_count
    end

  %{
    created_count: actual_created_count,
    duplicate_count: duplicate_count,
    invalid_count: invalid_count,
    total_processed: length(items),
    errors: other_errors,
    unique_constraint_errors: unique_constraint_errors
  }
end

# Execute the import
case Gel.start_link() do
  {:ok, client} ->
    case query_edgedb_terms.(client, limit) do
      {:ok, items} ->
        # Count total terms in database before import
        total_terms_before =
          Term
          |> Ash.read!()
          |> length()
        verify_import.(items)

        # result = process_import.(items)

        # # Count total terms in database after import
        # total_terms_after =
        #   Term
        #   |> Ash.read!()
        #   |> length()

        # IO.puts("✅ Import completed successfully!")
        # IO.puts("  Created: #{result.created_count}")
        # IO.puts("  Duplicates (skipped): #{result.duplicate_count}")
        # if result.invalid_count > 0 do
        #   IO.puts("  Invalid (missing name/description): #{result.invalid_count}")
        # end
        # IO.puts("  Total processed: #{result.total_processed}")
        # IO.puts("  Total terms in database: #{total_terms_before} → #{total_terms_after} (+#{total_terms_after - total_terms_before})")

        # if result.errors && length(result.errors) > 0 do
        #   IO.puts("\n⚠️  Other errors encountered:")
        #   Enum.each(result.errors, fn error ->
        #     IO.puts("  - #{inspect(error)}")
        #   end)
        # end

        # IO.puts("")

      {:error, reason} ->
        IO.puts("❌ Failed to query EdgeDB: #{inspect(reason)}")
        System.halt(1)
    end

  {:error, reason} ->
    IO.puts("❌ Failed to start Gel client: #{inspect(reason)}")
    System.halt(1)
end
