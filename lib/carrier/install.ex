defmodule Carrier.Install do
  require Logger
  alias Carrier.SSH
  import Carrier.Global, only: [
    ensure_target_env!: 1,
    ensure_deploy_config!: 1,
    remote_releases_dir: 0,
    parse_args!: 1,
  ]

  def install(args) do
    target_env = ensure_target_env!(args)
    config = ensure_deploy_config!(target_env)

    conn = SSH.init(config)
    install(conn, args)
  end

  def install(conn, args) do
    maybe_release_tag = target_release_tag(args)

    do_install(conn, maybe_release_tag)
  end

  def do_install(conn, maybe_release_tag) do
    try do
      Logger.info("Updating current symlink to release target: #{maybe_release_tag || "latest"}")
      ssh_duplicate_current_symlink!(conn)
      ssh_update_current_symlink!(conn, maybe_release_tag)

      Logger.info("Updated current symlink to: #{maybe_release_tag || "latest"}")
      {:ok, conn}
    rescue
      ex ->
        Logger.error("#{ex.message}")
        Logger.error("Restoring current symlink to prevoius")
        ssh_restore_current_symlink!(conn)
    end
  end

  defp target_release_tag(args) do
    {switches, _} = parse_args!(args)

    Keyword.get(switches, :target_release)
  end

  defp ssh_duplicate_current_symlink!(conn) do
    cmd = "[ -e current ] && cp -P current current_bak || exit 0"
    SSH.run!(conn, cmd)
  end

  defp ssh_restore_current_symlink!(conn) do
    cmd = "[ -e current_bak ] && mv current_bak current || exit 0"
    SSH.run!(conn, cmd)
  end

  # defp ssh_delete_backup_symlink!(conn) do
  #   cmd = "[ -e current_bak ] && rm current_bak"
  #   SSH.run!(conn, cmd)
  # end

  defp ssh_update_current_symlink!(conn, nil) do
    # Look up the latest release (by way of timestamped dir names)
    # and create a symlink to it as an access point
    cmd = "ls -r #{remote_releases_dir()} | head -n 1"
    cmd = "ln -sfn #{remote_releases_dir()}/`#{cmd}` current"
    SSH.run!(conn, cmd)
  end

  defp ssh_update_current_symlink!(conn, release_tag) when is_binary(release_tag) do
    cmd = "ln -sfn #{remote_releases_dir()}/#{release_tag} current"
    SSH.run!(conn, cmd)
  end
end
