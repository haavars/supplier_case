defmodule SupplierCase.ImportTest do
  use SupplierCase.DataCase

  alias SupplierCase.Import
  alias SupplierCase.Suppliers
  alias SupplierCase.Transactions

  @sample_csv_path "test/data/sample.csv"

  describe "import_csv/1" do
    test "imports suppliers and transactions from sample CSV" do
      result = Import.import_csv(@sample_csv_path)

      assert result.suppliers_imported > 0
      assert result.transactions_imported > 0
      assert result.chunks_processed > 0
      assert result.duplicates_skipped >= 0
    end

    test "handles duplicate imports by skipping them" do
      first_result = Import.import_csv(@sample_csv_path)
      
      second_result = Import.import_csv(@sample_csv_path)

      assert second_result.duplicates_skipped > 0
      assert second_result.transactions_imported < first_result.transactions_imported
    end

    test "correctly imports suppliers with VAT IDs" do
      Import.import_csv(@sample_csv_path)

      supplier = Suppliers.get_supplier_by_vat("998432980")
      assert supplier != nil
      assert supplier.name == "ICRON INC."
      assert supplier.country == "US"
    end

    test "correctly imports transactions with proper amounts" do
      Import.import_csv(@sample_csv_path)

      supplier = Suppliers.get_supplier_by_vat("998432980")
      transactions = Transactions.get_transactions_by_supplier(supplier.id)

      assert length(transactions) > 0
      
      first_transaction = List.first(transactions)
      assert first_transaction.invoice_number == "15286"
      assert Decimal.equal?(first_transaction.amount_nok, Decimal.new("74009.67"))
    end
  end
end
