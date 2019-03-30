defmodule Mix.Tasks.Carrier.Install do
  use Mix.Task

  def run(args) do
    Carrier.install(args)
  end
end
