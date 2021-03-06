defmodule Carrier.MixProject do
  use Mix.Project

  def project do
    [
      app: :carrier,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:uuid, "~> 1.1"},
      {:sshkit, "~> 0.1.0"},
      {:ssh_client_key_api, "~> 0.2.1"},
      {:ecto_sql, "~> 3.0.5"}
    ]
  end
end
