defmodule Mix.Tasks.Carrier.Build do
  use Mix.Task
  import Kitch.SystemUtil, only: [halt_with_error: 1]

  def run(args) do
    ensure_initialized!()

    Carrier.build(args)
  end

  defp ensure_initialized!() do
    case File.exists?("rel/config.exs") do
      true -> :ok
      false -> halt_with_error("Distillery is not initialized, run `mix carrier.init` first.")
    end
  end
end
