defmodule SupplierCase.Transactions do
  import Ecto.Query, warn: false
  alias SupplierCase.Repo
  alias SupplierCase.Transactions.Transaction

  def create_transaction(attrs) do
    %Transaction{}
    |> Transaction.changeset(attrs)
    |> Repo.insert()
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
