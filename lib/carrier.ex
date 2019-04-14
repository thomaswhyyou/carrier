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

  # TODO: Env var to configure cron, twitter subs..
  # TODO: check for primary when running migration
  # TODO: Add app rollback command, and include in deploy task
  # TODO: Include front end build in before_build hooks..

  # defdelegate rollback(config), to: Carrier.Rollback
end
