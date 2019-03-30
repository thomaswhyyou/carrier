defmodule Carrier.RepoRun do
  require Logger

  def migrate(), do: do_migrate(:up)

  def rollback(), do: do_migrate(:down)

  def seed(), do: do_seed()

  #
  # Private
  #

  @app Mix.Project.get.project[:app]

  defp ensure_all_started() do
    # app = Mix.Project.get.project[:app]

    Logger.info("==> Ensure all started: #{@app}.")
    Application.ensure_all_started(@app)
  end

  defp do_migrate(direction) when is_atom(direction) do
    {:ok, _} = ensure_all_started()

    repos = Application.get_env(@app, :ecto_repos, [])
    migrations_path = priv_path_to(@app, "repo/migrations")

    Logger.info("==> Running migration: #{direction}..")
    Enum.each(repos, fn repo ->
      Ecto.Migrator.run(repo, migrations_path, direction, all: true)
    end)

    Logger.info("==> Finished migration: #{direction}.")
    :init.stop()
  end

  defp do_seed() do
    {:ok, _} = ensure_all_started()

    seed_script = priv_path_to(@app, "repo/seeds.exs")

    if File.exists?(seed_script) do
      Code.eval_file(seed_script)
      Logger.info("==> Finished running seeds script.")
    else
      Logger.info("==> No seeds script detected, nothing more to do.")
    end

    :init.stop()
  end

  defp priv_path_to(app, subpath) do
    app
    |> :code.priv_dir()
    |> Path.join(subpath)
  end
end
