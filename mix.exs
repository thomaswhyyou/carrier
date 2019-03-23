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
      {:distillery, "~> 2.0", runtime: false},
      (if Mix.env() != :dev,
        do: {:kitch, git: "https://github.com/thomaswhyyou/kitch.ex.git"},
        else: {:kitch, path: "/Users/tyu/proj/kitch"}),

      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
    ]
  end
end
