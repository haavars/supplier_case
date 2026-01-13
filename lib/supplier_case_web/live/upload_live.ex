defmodule SupplierCaseWeb.UploadLive do
  use SupplierCaseWeb, :live_view
  alias SupplierCase.Import

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:uploaded_files, [])
      |> assign(:job_id, nil)
      |> assign(:job_status, nil)
      |> assign(:progress, nil)
      |> allow_upload(:csv_file, accept: ~w(.csv), max_entries: 1, max_file_size: 500_000_000)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("import", _params, socket) do
    uploaded_files =
      consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
        dest = Path.join(["priv", "uploads", "#{System.unique_integer([:positive])}.csv"])
        File.cp!(path, dest)
        {:ok, dest}
      end)

    case uploaded_files do
      [file_path] ->
        case Import.enqueue_csv_import(file_path) do
          {:ok, %Oban.Job{id: job_id}} ->
            Process.send_after(self(), :poll_progress, 1000)

            socket =
              socket
              |> assign(:job_id, job_id)
              |> assign(:job_status, "queued")
              |> assign(:progress, %{})

            {:noreply, socket}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to start import: #{inspect(reason)}")}
        end

      [] ->
        {:noreply, put_flash(socket, :error, "No file uploaded")}
    end
  end

  @impl true
  def handle_event("clear", _params, socket) do
    socket =
      socket
      |> assign(:job_id, nil)
      |> assign(:job_status, nil)
      |> assign(:progress, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_info(:poll_progress, socket) do
    case socket.assigns.job_id do
      nil ->
        {:noreply, socket}

      job_id ->
        job = SupplierCase.Repo.get(Oban.Job, job_id)

        case job do
          nil ->
            {:noreply, assign(socket, :job_status, "not_found")}

          job ->
            socket =
              socket
              |> assign(:job_status, job.state)
              |> assign(:progress, job.meta || %{})

            socket =
              if job.state in [:executing, :available, :scheduled] do
                Process.send_after(self(), :poll_progress, 1000)
                socket
              else
                socket
              end

            {:noreply, socket}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 py-8">
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">CSV Import</h1>
        <p class="mt-2 text-gray-600">Upload a CSV file to import suppliers and transactions</p>
      </div>

      <%= if @job_status in ["completed"] do %>
        <div class="bg-green-50 border border-green-200 rounded-lg p-6 mb-6">
          <div class="flex items-start">
            <.icon name="hero-check-circle" class="w-6 h-6 text-green-600 mt-0.5" />
            <div class="ml-3 flex-1">
              <h3 class="text-lg font-semibold text-green-900">Import Completed Successfully!</h3>
              <div class="mt-2 text-sm text-green-700">
                <p>Suppliers imported: {Map.get(@progress, "suppliers_imported", 0)}</p>
                <p>Transactions imported: {Map.get(@progress, "transactions_imported", 0)}</p>
                <p>Chunks processed: {Map.get(@progress, "chunks_processed", 0)}</p>
              </div>
              <div class="mt-4 flex gap-3">
                <.link
                  navigate={~p"/"}
                  class="inline-flex items-center px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700"
                >
                  View Suppliers
                </.link>
                <button
                  phx-click="clear"
                  class="inline-flex items-center px-4 py-2 bg-white text-green-700 border border-green-300 rounded-lg hover:bg-green-50"
                >
                  Upload Another File
                </button>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @job_status in ["executing", "available", "scheduled"] do %>
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-6">
          <div class="flex items-start">
            <.icon name="hero-arrow-path" class="w-6 h-6 text-blue-600 animate-spin mt-0.5" />
            <div class="ml-3 flex-1">
              <h3 class="text-lg font-semibold text-blue-900">Import in Progress</h3>
              <p class="mt-1 text-sm text-blue-700">
                Status: {format_status(@progress)}
              </p>
              <%= if Map.get(@progress, "transactions_imported") do %>
                <div class="mt-4">
                  <div class="flex justify-between text-sm text-blue-700 mb-1">
                    <span>Transactions imported</span>
                    <span>{Map.get(@progress, "transactions_imported", 0)}</span>
                  </div>
                  <div class="w-full bg-blue-200 rounded-full h-2">
                    <div class="bg-blue-600 h-2 rounded-full animate-pulse" style="width: 100%"></div>
                  </div>
                  <%= if Map.get(@progress, "chunks_processed") do %>
                    <p class="mt-2 text-xs text-blue-600">
                      Chunks processed: {Map.get(@progress, "chunks_processed", 0)}
                    </p>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @job_status in ["discarded", "cancelled"] do %>
        <div class="bg-red-50 border border-red-200 rounded-lg p-6 mb-6">
          <div class="flex items-start">
            <.icon name="hero-x-circle" class="w-6 h-6 text-red-600 mt-0.5" />
            <div class="ml-3 flex-1">
              <h3 class="text-lg font-semibold text-red-900">Import Failed</h3>
              <p class="mt-1 text-sm text-red-700">
                The import job was {@job_status}. Please try again.
              </p>
              <button
                phx-click="clear"
                class="mt-4 inline-flex items-center px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700"
              >
                Try Again
              </button>
            </div>
          </div>
        </div>
      <% end %>

      <%= if @job_status == nil do %>
        <div
          class="bg-white border-2 border-dashed border-gray-300 rounded-lg p-8"
          phx-drop-target={@uploads.csv_file.ref}
        >
          <form phx-submit="import" phx-change="validate" class="space-y-4">
            <div class="flex flex-col items-center justify-center">
              <.icon name="hero-document-arrow-up" class="w-16 h-16 text-gray-400 mb-4" />
              <div class="text-center">
                <label
                  for={@uploads.csv_file.ref}
                  class="cursor-pointer text-blue-600 hover:text-blue-700 font-medium"
                >
                  Click to upload
                </label>
                <span class="text-gray-600">or drag and drop</span>
              </div>
              <p class="text-sm text-gray-500 mt-2">CSV files up to 500MB</p>
            </div>

            <div class="mt-4">
              <.live_file_input upload={@uploads.csv_file} class="hidden" />
            </div>

            <%= for entry <- @uploads.csv_file.entries do %>
              <div class="flex items-center justify-between bg-gray-50 rounded-lg p-4">
                <div class="flex items-center gap-3">
                  <.icon name="hero-document" class="w-5 h-5 text-gray-500" />
                  <div>
                    <p class="text-sm font-medium text-gray-900">{entry.client_name}</p>
                    <p class="text-xs text-gray-500">
                      {Float.round(entry.client_size / 1_000_000, 2)} MB
                    </p>
                  </div>
                </div>
                <button
                  type="button"
                  phx-click="cancel-upload"
                  phx-value-ref={entry.ref}
                  class="text-red-600 hover:text-red-700"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>

              <%= for err <- upload_errors(@uploads.csv_file, entry) do %>
                <p class="text-sm text-red-600">{error_to_string(err)}</p>
              <% end %>
            <% end %>

            <%= if @uploads.csv_file.entries != [] do %>
              <button
                type="submit"
                class="w-full px-6 py-3 bg-blue-600 text-white font-medium rounded-lg hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
              >
                Start Import
              </button>
            <% end %>
          </form>
        </div>
      <% end %>

      <div class="mt-8">
        <.link
          navigate={~p"/"}
          class="inline-flex items-center text-blue-600 hover:text-blue-700"
        >
          <.icon name="hero-arrow-left" class="w-4 h-4 mr-2" /> Back to Suppliers Overview
        </.link>
      </div>
    </div>
    """
  end

  defp format_status(%{"status" => "processing_suppliers"}), do: "Processing suppliers..."
  defp format_status(%{"status" => "processing_transactions"}), do: "Processing transactions..."
  defp format_status(_), do: "Starting import..."

  defp error_to_string(:too_large), do: "File is too large (max 500MB)"
  defp error_to_string(:not_accepted), do: "Only CSV files are accepted"
  defp error_to_string(:too_many_files), do: "Only one file can be uploaded at a time"
end
