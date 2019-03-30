defmodule Mix.Tasks.Carrier.Deliver do
  use Mix.Task

  def run(args) do
    Carrier.deliver(args)
  end
end
