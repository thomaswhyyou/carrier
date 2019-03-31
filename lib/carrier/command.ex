defmodule Carrier.Command do
  require Logger

  import Carrier.Global,
    only: [
      ensure_target_env!: 1,
      ensure_deploy_config!: 1,
      parse_args!: 1,
      exec_current_app: 1
    ]

  alias Carrier.SSH

  @via_primary_only ["db_migrate", "db_rollback", "db_seed"]

  def command(args) do
    target_env = ensure_target_env!(args)
    config = ensure_deploy_config!(target_env)
    command = ensure_remote_command!(args)

    config = ensure_single_primary_maybe!(command, config)
    relay_command(command, config)
  end

  defp relay_command(command, config) do
    conn = SSH.init(config)

    try do
      Logger.info("Executing remote command: #{command}")
      SSH.run!(conn, exec_current_app(command))
    rescue
      ex -> Logger.error("#{ex.message}")
    end
  end

  defp ensure_remote_command!(args) do
    {switches, _} = parse_args!(args)

    Keyword.fetch!(switches, :remote_command)
  end

  defp ensure_single_primary_maybe!(command, config) when command in @via_primary_only do
    # TODO: For commands like db migration, there should only be one
    # primary host that should run.
    config
  end

  defp ensure_single_primary_maybe!(_command, config) do
    config
  end
end
