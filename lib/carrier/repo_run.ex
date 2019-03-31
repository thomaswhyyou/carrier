defmodule Carrier.RepoRun do
  require Logger

  # References:
  #
  # https://dreamconception.com/tech/phoenix-automated-build-and-deploy-made-simple/
  # https://hexdocs.pm/distillery/guides/running_migrations.html#migration-module

  @start_apps [
    :crypto,
    :ssl,
    :postgrex,
    :ecto,
    :ecto_sql,
    :telemetry,

    # extra_applications
    :logger
  ]

  def migrate() do
    start_services()
    do_migrate(:up)
    stop_services()
  end

  def rollback() do
    start_services()
    do_migrate(:down)
    stop_services()
  end

  def seed() do
    start_services()
    do_migrate(:up)
    do_seed()
    stop_services()
  end

  #
  # Private
  #

  defp ecto_repos!() do
    Application.fetch_env!(:carrier, :otp_app) |> Application.get_env(:ecto_repos, [])
  end

  defp start_services() do
    # Start apps necessary for executing migrations
    Enum.each(@start_apps, &Application.ensure_all_started/1)

    # Start the Repo(s) for app
    Logger.info("==> Starting repos..")

    # Switch pool_size to 2 for ecto > 3.0
    Enum.each(ecto_repos!(), & &1.start_link(pool_size: 2))
  end

  defp stop_services() do
    Logger.info("==> All done! Stopping services..")
    :init.stop()
  end

  defp do_migrate(direction) when is_atom(direction) do
    Enum.each(ecto_repos!(), fn repo -> do_migrate_for(repo, direction) end)
  end

  defp do_migrate_for(repo, direction) do
    app = Keyword.get(repo.config, :otp_app)
    Logger.info("==> Running migrations: #{direction} on #{app}..")

    migrations_path = priv_path_for(app, "repo/migrations")

    opts =
      case direction do
        :up -> [all: true]
        :down -> [step: 1]
      end

    Ecto.Migrator.run(repo, migrations_path, direction, opts)
  end

  defp do_seed() do
    Enum.each(ecto_repos!(), &do_seed_for/1)
  end

  defp do_seed_for(repo) do
    app = Keyword.get(repo.config, :otp_app)
    seeds_path = priv_path_for(app, "repo/seeds.exs")

    if File.exists?(seeds_path) do
      Logger.info("==> Running seeds for: #{app}..")
      Code.eval_file(seeds_path)
      Logger.info("==> Finished running seeds script.")
    else
      Logger.info("==> No seeds script detected, nothing more to do.")
    end
  end

  defp priv_path_for(app, subpath) do
    app
    |> :code.priv_dir()
    |> Path.join(subpath)
  end
end
