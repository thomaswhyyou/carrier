defmodule Mix.Tasks.Carrier.Stop do
  use Mix.Task

  def run(args) do
    # Don't error if not running already
    Carrier.command(args ++ ["--remote-command", "stop || true"])
  end
end
