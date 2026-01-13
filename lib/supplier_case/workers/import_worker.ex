defmodule SupplierCase.Workers.ImportWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3

  alias SupplierCase.Import
  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"file_path" => file_path}} = job) do
    Logger.info("Starting import job for file: #{file_path}")

    case File.exists?(file_path) do
      true ->
        result = Import.import_csv(file_path, job)

        Logger.info("Import completed: #{inspect(result)}")

        job
        |> Oban.Job.update(%{
          meta: %{
            status: "completed",
            suppliers_imported: result.suppliers_imported,
            transactions_imported: result.transactions_imported,
            chunks_processed: result.chunks_processed,
            duplicates_skipped: result.duplicates_skipped || 0
          }
        })
        |> SupplierCase.Repo.update!()

        :ok

      false ->
        Logger.error("File not found: #{file_path}")
        {:error, "File not found: #{file_path}"}
    end
  rescue
    error ->
      Logger.error("Import failed: #{inspect(error)}")
      {:error, Exception.message(error)}
  end
end
