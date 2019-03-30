defmodule Mix.Tasks.Carrier.Db.Seed do
  use Mix.Task

  def run(args) do
    Carrier.command(args ++ ["--remote-command", "db_seed"])
  end
end
