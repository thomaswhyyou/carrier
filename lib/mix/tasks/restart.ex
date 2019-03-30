defmodule Mix.Tasks.Carrier.Restart do
  use Mix.Task

  def run(args) do
    Mix.Task.run("carrier.stop", args)
    Mix.Task.run("carrier.start", args)
  end
end
