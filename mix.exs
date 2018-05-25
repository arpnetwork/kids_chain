defmodule KidsChain.MixProject do
  use Mix.Project

  def project do
    [
      app: :kids_chain,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {KidsChain.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.5"},
      {:cowboy, "~> 2.4"},
      {:poison, "~> 3.1"},
      {:prometheus_plugs, "~> 1.1"},
      {:distillery, "~> 1.5", runtime: false}
    ]
  end
end
