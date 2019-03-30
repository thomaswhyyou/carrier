defmodule Carrier do
  # Initialize distillery and etc.
  defdelegate init(args), to: Carrier.Init

  # Build the current release
  defdelegate build(args), to: Carrier.Build

  # Upload the current release to remote servers
  defdelegate deliver(args), to: Carrier.Deliver

  # Set current symlink to latest or target release
  defdelegate install(args), to: Carrier.Install
  defdelegate install(conn, args), to: Carrier.Install

  # Execute remote command with current app.
  # (app) ping, start, stop, restart
  # (db) migrate, rollback, seed
  defdelegate command(args), to: Carrier.Command

  # XXX: check for primary when running migration
  # TODO: Could not find static manifest at "/opt/app/byrdieapp/releases/20190326T065728-0.0.1/lib/syndi-0.0.1/priv/static/cache_manifest.json". Run "mix phx.digest" after building your static files or remove the configuration from "config/prod.exs".
  # TODO: Env var to configure cron, twitter subs..
  # TODO: Buil before_build hooks..

  # defdelegate rollback(config), to: Carrier.Rollback
end
