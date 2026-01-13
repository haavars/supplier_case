defmodule SupplierCase.Transactions do
  import Ecto.Query, warn: false
  alias SupplierCase.Repo
  alias SupplierCase.Transactions.Transaction
  require Logger

  def create_transaction(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Bulk insert transactions using Repo.insert_all for performance.
  Skips duplicates based on supplier_id, invoice_number, and invoice_date.
  Returns the count of inserted transactions and duplicates skipped.
  """
  def bulk_insert_transactions(transactions) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    transaction_entries =
      Enum.map(transactions, fn transaction ->
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

  def list_transactions do
    Repo.all(Transaction)
  end

  def get_transactions_by_supplier(supplier_id) do
    query =
      from t in Transaction,
        where: t.supplier_id == ^supplier_id,
        order_by: [desc: t.invoice_date]

    Repo.all(query)
  end

  def get_total_spend do
    query =
      from t in Transaction,
        select: sum(t.amount_nok)

    Repo.one(query) || Decimal.new(0)
  end

  def get_spend_by_supplier do
    query =
      from t in Transaction,
        group_by: t.supplier_id,
        select: {t.supplier_id, sum(t.amount_nok)}

    Repo.all(query)
    |> Map.new()
  end
end
