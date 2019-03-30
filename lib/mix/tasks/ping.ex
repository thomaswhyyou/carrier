defmodule Mix.Tasks.Carrier.Ping do
  use Mix.Task

  def run(args) do
    Carrier.command(args ++ ["--remote-command", "ping"])
  end
end
