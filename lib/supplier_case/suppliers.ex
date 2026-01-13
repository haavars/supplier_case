defmodule SupplierCase.Suppliers do
  import Ecto.Query, warn: false
  alias SupplierCase.Repo
  alias SupplierCase.Suppliers.Supplier

  def upsert_supplier(attrs) do
    %Supplier{}
    |> Supplier.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:name, :country, :nace_code, :updated_at]},
      conflict_target: :vat_id,
      returning: true
    )
  end

  def list_suppliers do
    Repo.all(Supplier)
  end

  def get_supplier(id) do
    Repo.get(Supplier, id)
  end

  def get_supplier_by_vat(vat_id) do
    Repo.get_by(Supplier, vat_id: vat_id)
  end

  def search_suppliers(search_term) do
    query =
      from s in Supplier,
        where: ilike(s.name, ^"%#{search_term}%"),
        order_by: s.name

    Repo.all(query)
  end
end
