defmodule SupplierCase.SuppliersTest do
  use SupplierCase.DataCase

  alias SupplierCase.Suppliers

  describe "bulk_upsert_suppliers_with_vat/1" do
    test "inserts multiple suppliers with VAT IDs" do
      suppliers = [
        %{name: "Acme Corp", country: "NO", vat_id: "NO123", nace_code: "62.01"},
        %{name: "Beta Inc", country: "SE", vat_id: "SE456", nace_code: "62.02"}
      ]

      result = Suppliers.bulk_upsert_suppliers_with_vat(suppliers)

      assert map_size(result) == 2
      assert Map.has_key?(result, {:vat, "NO123"})
      assert Map.has_key?(result, {:vat, "SE456"})
    end

    test "updates existing suppliers on conflict" do
      suppliers = [%{name: "Acme Corp", country: "NO", vat_id: "NO123", nace_code: "62.01"}]
      
      result1 = Suppliers.bulk_upsert_suppliers_with_vat(suppliers)
      first_id = result1[{:vat, "NO123"}]

      updated_suppliers = [%{name: "Acme Corp", country: "NO", vat_id: "NO123", nace_code: "62.99"}]
      result2 = Suppliers.bulk_upsert_suppliers_with_vat(updated_suppliers)
      second_id = result2[{:vat, "NO123"}]

      assert first_id == second_id
      
      supplier = Suppliers.get_supplier(first_id)
      assert supplier.nace_code == "62.99"
    end
  end

  describe "search_suppliers/1" do
    test "finds suppliers by partial name match" do
      suppliers = [
        %{name: "Acme Corp", country: "NO", vat_id: "NO1", nace_code: "62.01"},
        %{name: "Beta Inc", country: "SE", vat_id: "SE1", nace_code: "62.01"},
        %{name: "Acme International", country: "DK", vat_id: "DK1", nace_code: "62.01"}
      ]
      Suppliers.bulk_upsert_suppliers_with_vat(suppliers)

      results = Suppliers.search_suppliers("acme")

      assert length(results) == 2
      assert Enum.all?(results, fn s -> String.contains?(String.downcase(s.name), "acme") end)
    end
  end
end
