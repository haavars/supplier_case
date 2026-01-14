defmodule SupplierCase.TransactionsTest do
  use SupplierCase.DataCase

  alias SupplierCase.Suppliers
  alias SupplierCase.Transactions

  setup do
    suppliers = [%{name: "Test Corp", country: "NO", vat_id: "NO999", nace_code: "62.01"}]
    result = Suppliers.bulk_upsert_suppliers_with_vat(suppliers)
    supplier_id = result[{:vat, "NO999"}]

    %{supplier_id: supplier_id}
  end

  describe "bulk_insert_transactions/1" do
    test "inserts multiple transactions", %{supplier_id: supplier_id} do
      transactions = [
        %{
          supplier_id: supplier_id,
          invoice_number: "INV-001",
          invoice_date: ~D[2024-01-01],
          amount_nok: Decimal.new("1000.00")
        },
        %{
          supplier_id: supplier_id,
          invoice_number: "INV-002",
          invoice_date: ~D[2024-01-02],
          amount_nok: Decimal.new("2000.00")
        }
      ]

      result = Transactions.bulk_insert_transactions(transactions)

      assert result.inserted == 2
      assert result.duplicates == 0
    end

    test "skips duplicate transactions", %{supplier_id: supplier_id} do
      transaction = %{
        supplier_id: supplier_id,
        invoice_number: "INV-001",
        invoice_date: ~D[2024-01-01],
        amount_nok: Decimal.new("1000.00")
      }

      Transactions.bulk_insert_transactions([transaction])
      result = Transactions.bulk_insert_transactions([transaction])

      assert result.inserted == 0
      assert result.duplicates == 1
    end
  end

  describe "get_spend_by_supplier/0" do
    test "calculates total spend per supplier", %{supplier_id: supplier_id} do
      transactions = [
        %{
          supplier_id: supplier_id,
          invoice_number: "INV-001",
          invoice_date: ~D[2024-01-01],
          amount_nok: Decimal.new("1000.00")
        },
        %{
          supplier_id: supplier_id,
          invoice_number: "INV-002",
          invoice_date: ~D[2024-01-02],
          amount_nok: Decimal.new("2500.00")
        }
      ]

      Transactions.bulk_insert_transactions(transactions)
      spend_by_supplier = Transactions.get_spend_by_supplier()

      assert Decimal.equal?(spend_by_supplier[supplier_id], Decimal.new("3500.00"))
    end
  end
end
