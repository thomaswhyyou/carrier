defmodule Mix.Tasks.Carrier.Deploy do
  use Mix.Task

  def run(args) do
    Carrier.build(args)
    {:ok, conn, release_tag} = Carrier.deliver(args)

    args = args ++ ["--target-release", release_tag]
    {:ok, _} = Carrier.install(conn, args)

    # TODO: run migration, add commands

    # Mix.Task.run("carrier.restart", args)
  end
end
