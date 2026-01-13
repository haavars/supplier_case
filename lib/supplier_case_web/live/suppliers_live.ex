defmodule SupplierCaseWeb.SuppliersLive do
  use SupplierCaseWeb, :live_view
  import Ecto.Query
  alias SupplierCase.Repo
  alias SupplierCase.Suppliers.Supplier
  alias SupplierCase.Transactions.Transaction

  @impl true
  def mount(_params, _session, socket) do
    suppliers_with_spend = load_suppliers_with_spend()
    
    total_suppliers = length(suppliers_with_spend)
    total_spend = Enum.reduce(suppliers_with_spend, Decimal.new(0), fn supplier, acc ->
      Decimal.add(acc, supplier.total_spend || Decimal.new(0))
    end)

    socket =
      socket
      |> assign(:suppliers, suppliers_with_spend)
      |> assign(:total_suppliers, total_suppliers)
      |> assign(:total_spend, total_spend)

    {:ok, socket}
  end

  defp load_suppliers_with_spend do
    query =
      from s in Supplier,
        left_join: t in Transaction,
        on: t.supplier_id == s.id,
        group_by: s.id,
        select: %{
          id: s.id,
          name: s.name,
          vat_id: s.vat_id,
          country: s.country,
          nace_code: s.nace_code,
          total_spend: sum(t.amount_nok)
        },
        order_by: [desc: sum(t.amount_nok)]

    Repo.all(query)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 py-8">
      <div class="mb-8">
        <div class="flex items-center justify-between">
          <div>
            <h1 class="text-3xl font-bold text-gray-900">Suppliers Overview</h1>
            <p class="mt-2 text-gray-600">View and manage your supplier database</p>
          </div>
          <.link
            navigate={~p"/upload"}
            class="inline-flex items-center px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
          >
            <.icon name="hero-arrow-up-tray" class="w-5 h-5 mr-2" />
            Import CSV
          </.link>
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div class="bg-white rounded-lg shadow p-6 border border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Total Suppliers</p>
              <p class="mt-2 text-3xl font-bold text-gray-900">
                {format_number(@total_suppliers)}
              </p>
            </div>
            <div class="p-3 bg-blue-100 rounded-lg">
              <.icon name="hero-building-office" class="w-8 h-8 text-blue-600" />
            </div>
          </div>
        </div>

        <div class="bg-white rounded-lg shadow p-6 border border-gray-200">
          <div class="flex items-center justify-between">
            <div>
              <p class="text-sm font-medium text-gray-600">Total Spend</p>
              <p class="mt-2 text-3xl font-bold text-gray-900">
                {format_currency(@total_spend)}
              </p>
            </div>
            <div class="p-3 bg-green-100 rounded-lg">
              <.icon name="hero-currency-dollar" class="w-8 h-8 text-green-600" />
            </div>
          </div>
        </div>
      </div>

      <div class="bg-white rounded-lg shadow border border-gray-200">
        <div class="px-6 py-4 border-b border-gray-200">
          <h2 class="text-lg font-semibold text-gray-900">All Suppliers</h2>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Supplier
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Org nr
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Country
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Industry Code
                </th>
                <th class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">
                  Total Spend
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= if @suppliers == [] do %>
                <tr>
                  <td colspan="5" class="px-6 py-12 text-center text-gray-500">
                    <div class="flex flex-col items-center">
                      <.icon name="hero-inbox" class="w-12 h-12 text-gray-400 mb-3" />
                      <p class="text-lg font-medium">No suppliers found</p>
                      <p class="mt-1 text-sm">
                        <.link navigate={~p"/upload"} class="text-blue-600 hover:text-blue-700">
                          Import a CSV file
                        </.link>
                        to get started
                      </p>
                    </div>
                  </td>
                </tr>
              <% else %>
                <%= for supplier <- @suppliers do %>
                  <tr class="hover:bg-gray-50 transition-colors">
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm font-medium text-gray-900">{supplier.name}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">{supplier.vat_id}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">{supplier.country || "-"}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">{supplier.nace_code || "-"}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap text-right">
                      <div class="text-sm font-medium text-gray-900">
                        {format_currency(supplier.total_spend)}
                      </div>
                    </td>
                  </tr>
                <% end %>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>
    """
  end

  defp format_number(nil), do: "0"
  defp format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1 ")
    |> String.reverse()
  end

  defp format_currency(nil), do: "NOK 0"
  defp format_currency(%Decimal{} = amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string()
    |> format_currency_string()
  end

  defp format_currency_string(amount_str) do
    [integer_part, decimal_part] =
      case String.split(amount_str, ".") do
        [integer] -> [integer, "00"]
        [integer, decimal] -> [integer, String.pad_trailing(decimal, 2, "0")]
      end

    formatted_integer =
      integer_part
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1 ")
      |> String.reverse()

    "NOK #{formatted_integer}.#{decimal_part}"
  end
end
