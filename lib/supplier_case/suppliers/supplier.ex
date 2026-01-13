defmodule SupplierCase.Suppliers.Supplier do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Uniq.UUID, version: 7, autogenerate: true, type: :uuid}
  @foreign_key_type Uniq.UUID

  schema "suppliers" do
    field :vat_id, :string
    field :name, :string
    field :country, :string
    field :nace_code, :string

    has_many :transactions, SupplierCase.Transactions.Transaction

    timestamps()
  end

  def changeset(supplier, attrs) do
    supplier
    |> cast(attrs, [:vat_id, :name, :country, :nace_code])
    |> validate_required([:name])
    |> unique_constraint(:vat_id)
  end
end
