defmodule SupplierCase.Repo.Migrations.CreateTransactionsTable do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :supplier_id, references(:suppliers, type: :binary_id, on_delete: :restrict),
        null: false

      add :invoice_number, :string, null: false
      add :invoice_date, :date, null: false
      add :due_date, :date
      add :description, :text
      add :amount_nok, :decimal, precision: 15, scale: 2, null: false
      add :spend_category_l1, :string
      add :spend_category_l2, :string
      add :spend_category_l3, :string
      add :spend_category_l4, :string
      add :org_structure_l1, :string
      add :org_structure_l2, :string
      add :org_structure_l3, :string

      timestamps()
    end

    create unique_index(:transactions, [:supplier_id, :invoice_number])
    create index(:transactions, [:supplier_id])
    create index(:transactions, [:invoice_date])
  end
end
