defmodule Mix.Tasks.Carrier.Db.Rollback do
  use Mix.Task

  def run(args) do
    Carrier.command(args ++ ["--remote-command", "db_rollback"])
  end
end
