defmodule SupplierCaseWeb.SuppliersLive do
  use SupplierCaseWeb, :live_view
  import Ecto.Query
  alias SupplierCase.Repo
  alias SupplierCase.Suppliers.Supplier
  alias SupplierCase.Transactions.Transaction

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:search, "")
      |> assign(:country_filter, "")
      |> assign(:nace_filter, "")
      |> assign(:sort_by, :total_spend)
      |> assign(:sort_order, :desc)
      |> load_data()

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    socket =
      socket
      |> assign(:search, search)
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter", %{"country" => country, "nace" => nace}, socket) do
    socket =
      socket
      |> assign(:country_filter, country)
      |> assign(:nace_filter, nace)
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    socket =
      socket
      |> assign(:search, "")
      |> assign(:country_filter, "")
      |> assign(:nace_filter, "")
      |> load_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort", %{"column" => column}, socket) do
    column_atom = String.to_existing_atom(column)

    sort_order =
      if socket.assigns.sort_by == column_atom do
        toggle_sort_order(socket.assigns.sort_order)
      else
        :desc
      end

    socket =
      socket
      |> assign(:sort_by, column_atom)
      |> assign(:sort_order, sort_order)
      |> load_data()

    {:noreply, socket}
  end

  defp toggle_sort_order(:asc), do: :desc
  defp toggle_sort_order(:desc), do: :asc

  defp load_data(socket) do
    suppliers_with_spend =
      load_suppliers_with_spend(
        socket.assigns.search,
        socket.assigns.country_filter,
        socket.assigns.nace_filter,
        socket.assigns.sort_by,
        socket.assigns.sort_order
      )

    countries = load_unique_countries()
    nace_codes = load_unique_nace_codes()

    total_suppliers = length(suppliers_with_spend)

    total_spend =
      Enum.reduce(suppliers_with_spend, Decimal.new(0), fn supplier, acc ->
        Decimal.add(acc, supplier.total_spend || Decimal.new(0))
      end)

    socket
    |> assign(:suppliers, suppliers_with_spend)
    |> assign(:countries, countries)
    |> assign(:nace_codes, nace_codes)
    |> assign(:total_suppliers, total_suppliers)
    |> assign(:total_spend, total_spend)
  end

  def load_suppliers_with_spend(search, country_filter, nace_filter, sort_by, sort_order) do
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
          total_spend: sum(t.amount_nok),
          spend_category_l2: fragment("array_agg(DISTINCT ?)", t.spend_category_l2)
        }

    query = apply_search_filter(query, search)
    query = apply_country_filter(query, country_filter)
    query = apply_nace_filter(query, nace_filter)
    query = apply_sorting(query, sort_by, sort_order)

    Repo.all(query)
  end

  defp apply_search_filter(query, ""), do: query

  defp apply_search_filter(query, search) do
    search_pattern = "%#{search}%"

    from [s, ...] in query,
      where:
        ilike(s.name, ^search_pattern) or
          (not is_nil(s.vat_id) and ilike(s.vat_id, ^search_pattern))
  end

  defp apply_country_filter(query, ""), do: query

  defp apply_country_filter(query, country) do
    from [s, ...] in query,
      where: s.country == ^country
  end

  defp apply_nace_filter(query, ""), do: query

  defp apply_nace_filter(query, nace) do
    from [s, ...] in query,
      where: s.nace_code == ^nace
  end

  defp apply_sorting(query, :name, order) do
    from [s, ...] in query,
      order_by: [{^order, s.name}]
  end

  defp apply_sorting(query, :vat_id, order) do
    from [s, ...] in query,
      order_by: [{^order, s.vat_id}]
  end

  defp apply_sorting(query, :country, order) do
    from [s, ...] in query,
      order_by: [{^order, s.country}]
  end

  defp apply_sorting(query, :nace_code, order) do
    from [s, ...] in query,
      order_by: [{^order, s.nace_code}]
  end

  defp apply_sorting(query, :total_spend, order) do
    from [s, t] in query,
      order_by: [{^order, sum(t.amount_nok)}]
  end

  defp load_unique_countries do
    query =
      from s in Supplier,
        where: not is_nil(s.country),
        distinct: true,
        select: s.country,
        order_by: s.country

    Repo.all(query)
  end

  defp load_unique_nace_codes do
    query =
      from s in Supplier,
        where: not is_nil(s.nace_code),
        distinct: true,
        select: s.nace_code,
        order_by: s.nace_code

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
            <.icon name="hero-arrow-up-tray" class="w-5 h-5 mr-2" /> Import CSV
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
          <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
            <h2 class="text-lg font-semibold text-gray-900">All Suppliers</h2>

            <form phx-change="search" class="flex-1 max-w-md">
              <div class="relative">
                <input
                  type="text"
                  name="search"
                  value={@search}
                  placeholder="Search by name or VAT ID..."
                  class="w-full px-4 py-2 pl-10 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
                />
                <.icon
                  name="hero-magnifying-glass"
                  class="w-5 h-5 text-gray-400 absolute left-3 top-2.5"
                />
              </div>
            </form>
          </div>

          <form phx-change="filter" class="mt-4 flex flex-wrap gap-3">
            <div class="flex-1 min-w-[200px]">
              <select
                name="country"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">All Countries</option>
                <%= for country <- @countries do %>
                  <option value={country} selected={@country_filter == country}>
                    {country}
                  </option>
                <% end %>
              </select>
            </div>

            <div class="flex-1 min-w-[200px]">
              <select
                name="nace"
                class="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
              >
                <option value="">All Industry Codes</option>
                <%= for nace <- @nace_codes do %>
                  <option value={nace} selected={@nace_filter == nace}>
                    {nace}
                  </option>
                <% end %>
              </select>
            </div>

            <%= if @search != "" or @country_filter != "" or @nace_filter != "" do %>
              <button
                type="button"
                phx-click="clear_filters"
                class="px-4 py-2 text-sm text-gray-700 bg-gray-100 hover:bg-gray-200 rounded-lg transition-colors"
              >
                Clear Filters
              </button>
            <% end %>
          </form>
        </div>

        <div class="overflow-x-auto">
          <table class="min-w-full divide-y divide-gray-200">
            <thead class="bg-gray-50">
              <tr>
                <th
                  phx-click="sort"
                  phx-value-column="name"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                >
                  <div class="flex items-center gap-2">
                    Supplier {render_sort_icon(assigns, :name)}
                  </div>
                </th>
                <th
                  phx-click="sort"
                  phx-value-column="vat_id"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                >
                  <div class="flex items-center gap-2">
                    Org nr {render_sort_icon(assigns, :vat_id)}
                  </div>
                </th>
                <th
                  phx-click="sort"
                  phx-value-column="country"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                >
                  <div class="flex items-center gap-2">
                    Country {render_sort_icon(assigns, :country)}
                  </div>
                </th>
                <th
                  phx-click="sort"
                  phx-value-column="nace_code"
                  class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                >
                  <div class="flex items-center gap-2">
                    Industry Code {render_sort_icon(assigns, :nace_code)}
                  </div>
                </th>
                <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
                  <div class="flex items-center gap-2">
                    Spend Category L2
                  </div>
                </th>
                <th
                  phx-click="sort"
                  phx-value-column="total_spend"
                  class="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider cursor-pointer hover:bg-gray-100 select-none"
                >
                  <div class="flex items-center justify-end gap-2">
                    Total Spend {render_sort_icon(assigns, :total_spend)}
                  </div>
                </th>
              </tr>
            </thead>
            <tbody class="bg-white divide-y divide-gray-200">
              <%= if @suppliers == [] do %>
                <tr>
                  <td colspan="6" class="px-6 py-12 text-center text-gray-500">
                    <div class="flex flex-col items-center">
                      <.icon name="hero-inbox" class="w-12 h-12 text-gray-400 mb-3" />
                      <%= if @search != "" or @country_filter != "" or @nace_filter != "" do %>
                        <p class="text-lg font-medium">No suppliers found</p>
                        <p class="mt-1 text-sm">
                          Try adjusting your filters or
                          <button
                            phx-click="clear_filters"
                            class="text-blue-600 hover:text-blue-700"
                          >
                            clear all filters
                          </button>
                        </p>
                      <% else %>
                        <p class="text-lg font-medium">No suppliers found</p>
                        <p class="mt-1 text-sm">
                          <.link navigate={~p"/upload"} class="text-blue-600 hover:text-blue-700">
                            Import a CSV file
                          </.link>
                          to get started
                        </p>
                      <% end %>
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
                      <div class="text-sm text-gray-900">{supplier.vat_id || "-"}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">{supplier.country || "-"}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">{supplier.nace_code || "-"}</div>
                    </td>
                    <td class="px-6 py-4 whitespace-nowrap">
                      <div class="text-sm text-gray-900">
                        {if supplier.spend_category_l2,
                          do: Enum.join(supplier.spend_category_l2, ", "),
                          else: "-"}
                      </div>
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

  defp render_sort_icon(assigns, column) do
    if assigns.sort_by == column do
      if assigns.sort_order == :asc do
        ~H"""
        <.icon name="hero-chevron-up" class="w-4 h-4" />
        """
      else
        ~H"""
        <.icon name="hero-chevron-down" class="w-4 h-4" />
        """
      end
    else
      ~H"""
      <.icon name="hero-chevron-up-down" class="w-4 h-4 text-gray-300" />
      """
    end
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
