defmodule Mix.Tasks.Carrier.Db.Migrate do
  use Mix.Task

  def run(args) do
    Carrier.command(args ++ ["--remote-command", "db_migrate"])
  end
end
