defmodule KidsChain.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # Prometheus
    KidsChain.PipelineInstrumenter.setup()
    KidsChain.PrometheusExporter.setup()

    KidsChain.DB.start()

    # List all child processes to be supervised
    children = [
      KidsChain.KChain,
      KidsChain.ChainAgent,
      {Plug.Adapters.Cowboy2, scheme: :http, plug: KidsChain.Router, options: [port: 3000]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KidsChain.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
