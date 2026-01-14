defmodule SupplierCase.Repo.Migrations.UpdateTransactionUniqueConstraint do
  use Ecto.Migration

  def up do
    drop unique_index(:transactions, [:supplier_id, :invoice_number])

    create unique_index(:transactions, [:supplier_id, :invoice_number, :invoice_date],
             name: :transactions_supplier_invoice_date_index
           )

    create index(:transactions, [:supplier_id, :invoice_number])
  end

  def down do
    drop index(:transactions, [:supplier_id, :invoice_number])
    drop unique_index(:transactions, [:supplier_id, :invoice_number, :invoice_date])
    create unique_index(:transactions, [:supplier_id, :invoice_number])
  end
end
