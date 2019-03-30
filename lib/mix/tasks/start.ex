defmodule Mix.Tasks.Carrier.Start do
  use Mix.Task

  def run(args) do
    Carrier.command(args ++ ["--remote-command", "start"])
  end
end
