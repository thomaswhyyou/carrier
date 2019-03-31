defmodule Carrier.Deliver do
  require Mix.Config
  require Logger

  import Carrier.Global, only: [
    ensure_target_env!: 1,
    ensure_deploy_config!: 1,
    release_tarball_dist_path: 1,
    release_envrc_dist_path: 1,
    remote_releases_dir: 0,
    app_version: 0,
    tarball_filename: 0,
    envrc_filename: 0,
    halt_with_error: 1,
    sys_cmd!: 2,
  ]
  alias Carrier.SSH


  def deliver(args) do
    # Local source files
    target_env = ensure_target_env!(args)
    tarball_path = locate_release_tarball!(target_env)
    envrc_path = locate_release_envrc(target_env)

    config = ensure_deploy_config!(target_env)
    do_deliver(tarball_path, envrc_path, config)
  end

  defp do_deliver(tarball_path, envrc_path, config) do
    # Remote targets
    release_tag = "#{current_timestamp_tag()}-#{app_version()}"
    release_dir = Path.join(remote_releases_dir(), release_tag)
    remote_path = Path.join(release_dir, tarball_filename())

    conn = SSH.init(config)

    try do
      # Upload tarball
      Logger.info("Uploading release archive: #{remote_path}")
      SSH.run!(conn, "mkdir -p #{release_dir}")
      SSH.upload(conn, tarball_path, remote_path)

      # Unpack tarball
      Logger.info("Unpacking release archive..")
      SSH.run!(conn, "tar zxvf #{remote_path} -C #{release_dir}")

      # If envrc, run ansible to place it in release dir
      ansible_forward_envrc!(envrc_path, release_dir, config)

      {:ok, conn, release_tag}
    rescue
      ex ->
        Logger.error("#{ex.message}")
        Logger.error("Cleaning up failed release..")
        SSH.run!(conn, "rm -rf #{release_dir}")
    end
  end

  defp locate_release_tarball!(target_env) do
    tarball = release_tarball_dist_path(target_env)

    case File.exists?(tarball) do
      true -> tarball
      false -> halt_with_error("Unable to locate #{tarball}")
    end
  end

  defp locate_release_envrc(target_env) do
    envrc = release_envrc_dist_path(target_env)

    case File.exists?(envrc) do
      true -> envrc
      false -> nil
    end
  end

  def ansible_forward_envrc!(nil, _release_dir, _config), do: :noop

  def ansible_forward_envrc!(envrc_path, release_dir, %{inventory: inventory} = config) do
    ssh_hosts = SSH.to_sshkit_hosts(inventory)

    Enum.each(ssh_hosts, fn ssh_host ->
      ansible_forward_envrc!(envrc_path, release_dir, config, ssh_host)
    end)
  end

  def ansible_forward_envrc!(envrc_path, release_dir, %{options: options} = _config, %SSHKit.Host{} = host) do
    ansible_user = Keyword.fetch!(host.options, :user)
    private_key = Keyword.fetch!(host.options, :identity)
    workspace = Keyword.fetch!(options, :workspace)
    vault_password_file = Keyword.fetch!(options, :vault_password_file)

    # Comma separated host name list, need a dangling comma even if one. :\
    inventory = host.name <> ","

    copy_src = Path.expand(envrc_path)
    copy_dest = Path.join([ workspace, release_dir, envrc_filename() ])
    copy_args = Enum.join([
      "src=#{copy_src}",
      "dest=#{copy_dest}",
      "decrypt=yes",
    ], " ")

    extra_args = Enum.join([
      "ansible_user=#{ansible_user}",
      "ansible_python_interpreter=/usr/bin/python3",  # Use python3
    ], " ")

    all_args = [
      "all",
      "-v",
      "-i", inventory,
      "-m", "copy",
      "-a", copy_args,
      "-e", extra_args,
      "--private-key=#{private_key}",
      "--vault-password-file=#{vault_password_file}"
    ]

    cmd = "ansible " <> Enum.join(all_args, " ")

    Logger.info("Forwarding envrc with ansible: #{cmd}")
    sys_cmd!("ansible", all_args)
  end

  defp current_timestamp_tag() do
    # "2017-12-19T17:17:36.134976Z" -> "20171219T171736"
    DateTime.utc_now()
    |> DateTime.to_iso8601()
    |> String.split(".")
    |> List.first()
    |> String.replace("-", "")
    |> String.replace(":", "")
  end
end
