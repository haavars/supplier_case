defmodule SupplierCase.Repo.Migrations.MakeVatIdNullable do
  use Ecto.Migration

  def up do
    drop unique_index(:suppliers, [:vat_id])
    
    alter table(:suppliers) do
      modify :vat_id, :string, null: true
    end
    
    create unique_index(:suppliers, [:vat_id], where: "vat_id IS NOT NULL")
    create unique_index(:suppliers, [:name, :country, :vat_id], name: :suppliers_name_country_vat_index)
  end

  def down do
    drop unique_index(:suppliers, [:name, :country, :vat_id], name: :suppliers_name_country_vat_index)
    drop unique_index(:suppliers, [:vat_id])
    
    alter table(:suppliers) do
      modify :vat_id, :string, null: false
    end
    
    create unique_index(:suppliers, [:vat_id])
  end
end
