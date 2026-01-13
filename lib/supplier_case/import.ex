defmodule SupplierCase.Import do
  alias SupplierCase.Repo
  alias SupplierCase.Suppliers.Supplier
  alias SupplierCase.Transactions.Transaction
  require Logger

  NimbleCSV.define(CSVParser, separator: ";", escape: "\"")

  @chunk_size 3000

  def import_csv(file_path, job \\ nil) do
    Logger.info("Starting CSV import from #{file_path}")

    suppliers_result = extract_and_import_suppliers(file_path, job)
    vat_to_uuid_map = suppliers_result.vat_to_uuid_map

    Logger.info("Imported #{suppliers_result.count} suppliers")

    if job do
      job
      |> Oban.Job.update(%{
        meta: %{
          status: "processing_transactions",
          suppliers_imported: suppliers_result.count
        }
      })
      |> Repo.update!()
    end

    transactions_result = import_transactions_in_chunks(file_path, vat_to_uuid_map, job)

    Logger.info(
      "Imported #{transactions_result.count} transactions in #{transactions_result.chunks} chunks. " <>
        "Skipped #{transactions_result.duplicates} duplicates."
    )

    %{
      suppliers_imported: suppliers_result.count,
      transactions_imported: transactions_result.count,
      chunks_processed: transactions_result.chunks,
      duplicates_skipped: transactions_result.duplicates
    }
  end

  defp extract_and_import_suppliers(file_path, job) do
    if job do
      job
      |> Oban.Job.update(%{meta: %{status: "processing_suppliers"}})
      |> Repo.update!()
    end

    unique_suppliers =
      file_path
      |> File.stream!()
      |> CSVParser.parse_stream(skip_headers: true)
      |> Stream.map(&parse_supplier_from_row/1)
      |> Enum.reduce(%{}, fn supplier, acc ->
        Map.put_new(acc, supplier.vat_id, supplier)
      end)
      |> Map.values()

    vat_to_uuid_map = bulk_insert_suppliers(unique_suppliers)

    %{count: map_size(vat_to_uuid_map), vat_to_uuid_map: vat_to_uuid_map}
  end

  defp parse_supplier_from_row(row) do
    [
      supplier,
      _supplier_name_original,
      _invoice_number,
      _invoice_date,
      _due_date,
      _description_spend_table,
      supplier_country,
      vat_id,
      nace | _rest
    ] = row

    %{
      vat_id: String.trim(vat_id),
      name: String.trim(supplier),
      country: String.trim(supplier_country),
      nace_code: String.trim(nace)
    }
  end

  defp bulk_insert_suppliers(suppliers) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    supplier_entries =
      Enum.map(suppliers, fn supplier ->
        %{
          id: Uniq.UUID.uuid7(:default),
          vat_id: supplier.vat_id,
          name: supplier.name,
          country: supplier.country,
          nace_code: supplier.nace_code,
          inserted_at: now,
          updated_at: now
        }
      end)

    {_count, returned} =
      Repo.insert_all(
        Supplier,
        supplier_entries,
        on_conflict: {:replace, [:name, :country, :nace_code, :updated_at]},
        conflict_target: :vat_id,
        returning: [:id, :vat_id]
      )

    Map.new(returned, fn supplier -> {supplier.vat_id, supplier.id} end)
  end

  defp import_transactions_in_chunks(file_path, vat_to_uuid_map, job) do
    file_path
    |> File.stream!()
    |> CSVParser.parse_stream(skip_headers: true)
    |> Stream.map(&parse_transaction_from_row(&1, vat_to_uuid_map))
    |> Stream.reject(&is_nil/1)
    |> Stream.chunk_every(@chunk_size)
    |> Stream.with_index(1)
    |> Enum.reduce(%{count: 0, chunks: 0, duplicates: 0}, fn {chunk, chunk_index}, acc ->
      result = insert_transaction_chunk(chunk)

      if job do
        job
        |> Oban.Job.update(%{
          meta: %{
            status: "processing_transactions",
            chunks_processed: chunk_index,
            transactions_imported: acc.count + result.inserted,
            duplicates_skipped: acc.duplicates + result.duplicates
          }
        })
        |> Repo.update!()
      end

      %{
        count: acc.count + result.inserted,
        chunks: chunk_index,
        duplicates: acc.duplicates + result.duplicates
      }
    end)
  end

  defp parse_transaction_from_row(row, vat_to_uuid_map) do
    [
      _supplier,
      _supplier_name_original,
      invoice_number,
      invoice_date,
      due_date,
      description_spend_table,
      _supplier_country,
      vat_id,
      _nace,
      transaction_value_nok,
      spend_category_l1,
      spend_category_l2,
      spend_category_l3,
      spend_category_l4,
      org_structure_l1,
      org_structure_l2,
      org_structure_l3
    ] = row

    vat_id_trimmed = String.trim(vat_id)
    supplier_id = Map.get(vat_to_uuid_map, vat_id_trimmed)

    unless supplier_id do
      Logger.warning("No supplier found for VAT ID: #{inspect(vat_id_trimmed)}")
    end

    if supplier_id do
      %{
        supplier_id: supplier_id,
        invoice_number: invoice_number,
        invoice_date: parse_date(invoice_date),
        due_date: parse_date(due_date),
        description: description_spend_table,
        amount_nok: parse_decimal(transaction_value_nok),
        spend_category_l1: spend_category_l1,
        spend_category_l2: spend_category_l2,
        spend_category_l3: spend_category_l3,
        spend_category_l4: spend_category_l4,
        org_structure_l1: org_structure_l1,
        org_structure_l2: org_structure_l2,
        org_structure_l3: org_structure_l3
      }
    else
      nil
    end
  end

  defp insert_transaction_chunk(chunk) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    transaction_entries =
      Enum.map(chunk, fn transaction ->
        Map.merge(transaction, %{inserted_at: now, updated_at: now})
      end)

    {count, _} =
      Repo.insert_all(
        Transaction,
        transaction_entries,
        on_conflict: :nothing,
        conflict_target: [:supplier_id, :invoice_number, :invoice_date]
      )

    duplicates_skipped = length(transaction_entries) - count

    if duplicates_skipped > 0 do
      Logger.warning(
        "Skipped #{duplicates_skipped} duplicate transactions (same supplier_id, invoice_number, and invoice_date)"
      )
    end

    %{inserted: count, duplicates: duplicates_skipped}
  end

  defp parse_date(""), do: nil
  defp parse_date(nil), do: nil

  defp parse_date(date_string) do
    date_string
    |> String.split("T")
    |> List.first()
    |> case do
      nil ->
        nil

      date_part ->
        case Date.from_iso8601(date_part) do
          {:ok, date} -> date
          {:error, _} -> nil
        end
    end
  end

  defp parse_decimal(""), do: Decimal.new(0)
  defp parse_decimal(nil), do: Decimal.new(0)

  defp parse_decimal(amount_string) do
    case Decimal.parse(amount_string) do
      {decimal, _} -> decimal
      :error -> Decimal.new(0)
    end
  end

  def enqueue_csv_import(file_path) do
    %{file_path: file_path}
    |> SupplierCase.Workers.ImportWorker.new(queue: :default)
    |> Oban.insert()
  end
end
