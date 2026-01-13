defmodule SupplierCase.Repo.Migrations.CreateSuppliersTable do
  use Ecto.Migration

  def change do
    create table(:suppliers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :vat_id, :string, null: false
      add :name, :string, null: false
      add :country, :string
      add :nace_code, :string

      timestamps()
    end

    create unique_index(:suppliers, [:vat_id])
  end
end
