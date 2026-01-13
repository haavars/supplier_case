defmodule SupplierCase.Transactions.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :invoice_number, :string
    field :invoice_date, :date
    field :due_date, :date
    field :description, :string
    field :amount_nok, :decimal
    field :spend_category_l1, :string
    field :spend_category_l2, :string
    field :spend_category_l3, :string
    field :spend_category_l4, :string
    field :org_structure_l1, :string
    field :org_structure_l2, :string
    field :org_structure_l3, :string

    belongs_to :supplier, SupplierCase.Suppliers.Supplier, type: Uniq.UUID

    timestamps()
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :supplier_id,
      :invoice_number,
      :invoice_date,
      :due_date,
      :description,
      :amount_nok,
      :spend_category_l1,
      :spend_category_l2,
      :spend_category_l3,
      :spend_category_l4,
      :org_structure_l1,
      :org_structure_l2,
      :org_structure_l3
    ])
    |> validate_required([:supplier_id, :invoice_number, :invoice_date, :amount_nok])
    |> unique_constraint([:supplier_id, :invoice_number])
  end
end
