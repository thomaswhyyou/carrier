defmodule Mix.Tasks.Carrier.Init do
  use Mix.Task

  def run(args) do
    Carrier.init(args)
  end
end
