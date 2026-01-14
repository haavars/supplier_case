defmodule SupplierCase.Import do
  alias SupplierCase.Repo
  alias SupplierCase.Suppliers
  alias SupplierCase.Transactions
  require Logger

  NimbleCSV.define(CSVParser, separator: ";", escape: "\"")

  @chunk_size 3000

  def import_csv(file_path, job \\ nil) do
    Logger.info("Starting CSV import from #{file_path}")

    suppliers_result = extract_and_import_suppliers(file_path, job)
    identifier_to_uuid_map = suppliers_result.identifier_map

    Logger.info("Imported #{suppliers_result.count} suppliers")

    if job do
      update_job_meta(job, %{
        status: "processing_transactions",
        suppliers_imported: suppliers_result.count
      })
    end

    transactions_result = import_transactions_in_chunks(file_path, identifier_to_uuid_map, job)

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
      update_job_meta(job, %{status: "processing_suppliers"})
    end

    unique_suppliers =
      file_path
      |> File.stream!()
      |> CSVParser.parse_stream(skip_headers: true)
      |> Stream.map(&parse_supplier_from_row/1)
      |> Enum.reduce(%{}, fn supplier, acc ->
        key = supplier_key(supplier)
        Map.put_new(acc, key, supplier)
      end)
      |> Map.values()

    identifier_to_uuid_map = upsert_suppliers(unique_suppliers)

    %{count: map_size(identifier_to_uuid_map), identifier_map: identifier_to_uuid_map}
  end

  defp supplier_key(%{vat_id: vat_id}) when not is_nil(vat_id), do: {:vat, vat_id}
  defp supplier_key(%{name: name, country: country}), do: {:name_country, name, country}

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

    trimmed_vat_id = String.trim(vat_id)
    vat_id_value = if trimmed_vat_id == "", do: nil, else: trimmed_vat_id

    trimmed_country = String.trim(supplier_country)
    country_value = if trimmed_country == "", do: nil, else: trimmed_country

    %{
      vat_id: vat_id_value,
      name: String.trim(supplier),
      country: country_value,
      nace_code: String.trim(nace)
    }
  end

  defp upsert_suppliers(suppliers) do
    {suppliers_with_vat, suppliers_without_vat} =
      Enum.split_with(suppliers, fn s -> not is_nil(s.vat_id) end)

    identifier_map_with_vat =
      if suppliers_with_vat != [] do
        Suppliers.bulk_upsert_suppliers_with_vat(suppliers_with_vat)
      else
        %{}
      end

    identifier_map_without_vat =
      if suppliers_without_vat != [] do
        Suppliers.upsert_suppliers_without_vat(suppliers_without_vat)
      else
        %{}
      end

    Map.merge(identifier_map_with_vat, identifier_map_without_vat)
  end

  defp import_transactions_in_chunks(file_path, identifier_to_uuid_map, job) do
    file_path
    |> File.stream!()
    |> CSVParser.parse_stream(skip_headers: true)
    |> Stream.map(&parse_transaction_from_row(&1, identifier_to_uuid_map))
    |> Stream.reject(&is_nil/1)
    |> Stream.chunk_every(@chunk_size)
    |> Stream.with_index(1)
    |> Enum.reduce(%{count: 0, chunks: 0, duplicates: 0}, fn {chunk, chunk_index}, acc ->
      result = Transactions.bulk_insert_transactions(chunk)

      if job do
        update_job_meta(job, %{
          status: "processing_transactions",
          chunks_processed: chunk_index,
          transactions_imported: acc.count + result.inserted,
          duplicates_skipped: acc.duplicates + result.duplicates
        })
      end

      %{
        count: acc.count + result.inserted,
        chunks: chunk_index,
        duplicates: acc.duplicates + result.duplicates
      }
    end)
  end

  defp parse_transaction_from_row(row, identifier_to_uuid_map) do
    [
      supplier_name,
      _supplier_name_original,
      invoice_number,
      invoice_date,
      due_date,
      description_spend_table,
      supplier_country,
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
    vat_id_value = if vat_id_trimmed == "", do: nil, else: vat_id_trimmed

    trimmed_country = String.trim(supplier_country)
    country_value = if trimmed_country == "", do: nil, else: trimmed_country

    supplier_id =
      if vat_id_value do
        Map.get(identifier_to_uuid_map, {:vat, vat_id_value})
      else
        Map.get(
          identifier_to_uuid_map,
          {:name_country, String.trim(supplier_name), country_value}
        )
      end

    unless supplier_id do
      Logger.warning(
        "No supplier found for: #{inspect(%{vat_id: vat_id_value, name: supplier_name, country: supplier_country})}"
      )
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

  defp update_job_meta(job, meta) do
    job
    |> Oban.Job.update(%{meta: meta})
    |> Repo.update!()
  end

  def enqueue_csv_import(file_path) do
    %{file_path: file_path}
    |> SupplierCase.Workers.ImportWorker.new(queue: :default)
    |> Oban.insert()
  end
end
