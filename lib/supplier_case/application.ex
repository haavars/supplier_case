defmodule SupplierCase.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SupplierCaseWeb.Telemetry,
      SupplierCase.Repo,
      {DNSCluster, query: Application.get_env(:supplier_case, :dns_cluster_query) || :ignore},
      {Oban, Application.fetch_env!(:supplier_case, Oban)},
      {Phoenix.PubSub, name: SupplierCase.PubSub},
      # Start a worker by calling: SupplierCase.Worker.start_link(arg)
      # {SupplierCase.Worker, arg},
      # Start to serve requests, typically the last entry
      SupplierCaseWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SupplierCase.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SupplierCaseWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
