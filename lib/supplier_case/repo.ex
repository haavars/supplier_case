defmodule SupplierCase.Repo do
  use Ecto.Repo,
    otp_app: :supplier_case,
    adapter: Ecto.Adapters.Postgres
end
