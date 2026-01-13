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

  @doc """
  Bulk insert suppliers with VAT IDs using Repo.insert_all for performance.
  Returns a map of {:vat, vat_id} => supplier_id.
  """
  def bulk_upsert_suppliers_with_vat(suppliers) do
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
        on_conflict: {:replace, [:nace_code, :updated_at]},
        conflict_target: [:name, :country, :vat_id],
        returning: [:id, :vat_id]
      )

    Map.new(returned, fn supplier -> {{:vat, supplier.vat_id}, supplier.id} end)
  end

  @doc """
  Upserts suppliers without VAT IDs one by one.
  Returns a map of {:name_country, name, country} => supplier_id.
  """
  def upsert_suppliers_without_vat(suppliers) do
    Enum.reduce(suppliers, %{}, fn supplier, acc ->
      query =
        if supplier.country do
          from s in Supplier,
            where: s.name == ^supplier.name and s.country == ^supplier.country and is_nil(s.vat_id),
            limit: 1
        else
          from s in Supplier,
            where: s.name == ^supplier.name and is_nil(s.country) and is_nil(s.vat_id),
            limit: 1
        end

      existing_supplier = Repo.one(query)

      supplier_id =
        if existing_supplier do
          existing_supplier
          |> Supplier.changeset(%{nace_code: supplier.nace_code})
          |> Repo.update!()

          existing_supplier.id
        else
          {:ok, inserted} =
            %Supplier{}
            |> Supplier.changeset(supplier)
            |> Repo.insert()

          inserted.id
        end

      Map.put(acc, {:name_country, supplier.name, supplier.country}, supplier_id)
    end)
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
