defmodule Carrier do

  defdelegate init(config), to: Carrier.Init
  defdelegate build(config), to: Carrier.Build
  # defdelegate publish(config), to: Carrier.Publish
  # defdelegate ship(config), to: Carrier.Ship
  # defdelegate install(config), to: Carrier.Install
  # defdelegate restart(config), to: Carrier.Restart
  # defdelegate green_flag(config), to: Carrier.GreenFlag
  # defdelegate rollback(config), to: Carrier.Rollback
  # defdelegate exec(config, cmd, switches), to: Carrier.Exec

  # TODO:
  # + Need to do Moa.Nexus.Repo.Runner somewhere
  # + also refactor these to make it more general, and use SSHKit directly and remove bootleg dependency
  #
  # + re-write carrier
  # + write ansible for ssl
  # + figure out webpack stuff ughh
  # + release the kraken

  # # Local
  # @tmp_dir "./_carrier"
  # @dist_dir "./_dist"
  # @config_envrc_dir "./config/envrc"
  #
  # # Remote
  # @releases_to "./releases"
  #
  # alias Bootleg.{SSH}
  # alias Moa.Pylon.PrintUtil, as: Print
  #
  #
  # def main(args, cmd) when is_atom(cmd) do
  #   apply(__MODULE__, cmd, [args])
  # end
  #
  # # TODO:
  # # + Should probably upload to S3 when successfully deployed? (w/ encrypted envrc)
  # # + Maybe command for Docker cleanup?
  # # + Also ensure ansible-vault is present.. for deploy?
  #
  # def deploy(args) do
  #   # Local source files
  #   target_env = ensure_target_env!(args)
  #   tarball_path = locate_release_tarball!(target_env)
  #   envrc_path = locate_release_envrc(target_env)
  #
  #   # Remote targets
  #   release_tag = "#{timestamp_utc_now()}-#{app_version()}"
  #   release_dir = Path.join(@releases_to, release_tag)
  #   remote_path = Path.join(release_dir, named_tarball())
  #
  #   Bootleg.Config.env(target_env)
  #   hosts = inventory_hosts_for_role(:app)
  #   conn = SSH.init(:app)
  #
  #   try do
  #     # Upload tarball
  #     Print.info("Uploading release archive: #{remote_path}")
  #     SSH.run!(conn, "mkdir -p #{release_dir}")
  #     SSH.upload(conn, tarball_path, remote_path)
  #
  #     # Unpack tarball
  #     Print.info("Unpacking release archive..")
  #     SSH.run!(conn, "tar zxvf #{remote_path} -C #{release_dir}")
  #
  #     # If envrc, run ansible to place it in release dir
  #     ansible_forward_envrc!(envrc_path, release_dir, hosts)
  #
  #     Print.info("Updating current symlink..")
  #     ssh_update_current_symlink!(conn)
  #
  #     Print.info("Run migration up, as needed..")
  #     SSH.run!(conn, current_exec(:db_migrate))
  #
  #     Print.info("Bouncing app..")
  #     ssh_stop_current!(conn, :silent)
  #     ssh_start_current!(conn)
  #
  #   rescue
  #     ex ->
  #       Print.error("#{ex.message}")
  #       Print.error("Cleaning up failed release and update current symlink..")
  #
  #       # Delete attempted release and revert current symlink
  #       # back to last good release.
  #       SSH.run!(conn, "rm -rf #{release_dir}")
  #       ssh_update_current_symlink!(conn)
  #   end
  # end
  #
  # def shipit(args) do
  #   build(args)
  #   deploy(args)
  # end
  #
  # # TODO:
  # # + Need to have rollback cmd,
  # # + arg for if migration rollback,
  # # + arg for if frontend rollback.
  # # def rollback(args) do
  # # end
  #
  # def relay_cmd(args, cmd) when is_atom(cmd) do
  #   target_env = ensure_target_env!(args)
  #   Bootleg.Config.env(target_env)
  #   conn = SSH.init(:app)
  #
  #   Print.info("Relaying command: #{cmd}")
  #   SSH.run!(conn, current_exec(cmd))
  # end
  #
  #
  # #
  # # Private
  # #
  #
  # # Remote commands
  #
  # defp current_exec(), do: "./current/bin/#{app_name()}"
  # defp current_exec(cmd), do: "#{current_exec()} #{cmd}"
  #
  # defp ssh_start_current!(conn) do
  #   SSH.run!(conn, current_exec("start"))
  #   Print.info("Started.")
  # end
  #
  # defp ssh_restart_current!(conn) do
  #   SSH.run!(conn, current_exec("restart"))
  #   Print.info("Restarted.")
  # end
  #
  # defp ssh_stop_current!(conn) do
  #   SSH.run!(conn, current_exec("stop"))
  #   Print.info("Stopped.")
  # end
  # defp ssh_stop_current!(conn, :silent) do
  #   cmd = "#{current_exec()} describe && (#{current_exec()} stop || true)"
  #   SSH.run!(conn, cmd)
  #   Print.info("Stopped.")
  # end
  #
  # defp ssh_update_current_symlink!(conn) do
  #   # Look up the latest release (by way of timestamped dir names)
  #   # and create a symlink to it as an access point
  #   cmd = "ls -r #{@releases_to} | head -n 1"
  #   cmd = "ln -sfn #{@releases_to}/`#{cmd}` current"
  #   SSH.run!(conn, cmd)
  # end
  #
  # defp ansible_forward_envrc!(nil, _release_dir, _hosts), do: :noop
  # defp ansible_forward_envrc!(envrc_path, release_dir, hosts) do
  #   # Assume below options are all uniform across app hosts and
  #   # they exist, so take the first one as a representative.
  #   %Bootleg.Host{ options: options } = List.first(hosts)
  #   ansible_user = Keyword.fetch!(options, :user)
  #   private_key = Keyword.fetch!(options, :identity)
  #   workspace = Keyword.fetch!(options, :workspace)
  #
  #   # Comma separated host name list.
  #   inventory =
  #     hosts
  #     |> Enum.map(&(&1.host.name))
  #     |> Enum.join(",")
  #     |> Kernel.<>(",")  # NEED this comma at the end for ansible!! T-T
  #
  #   vault_password_file =
  #     Application.get_env(:carrier, :vault_password_file, "~/.vault_password")
  #     |> Path.expand()
  #
  #   copy_src = Path.expand(envrc_path)
  #   copy_dest = Path.join([ workspace, release_dir, named_envrc() ])
  #   copy_args = Enum.join([
  #     "src=#{copy_src}",
  #     "dest=#{copy_dest}",
  #     "decrypt=yes",
  #   ], " ")
  #
  #   extra_args = Enum.join([
  #     "ansible_user=#{ansible_user}",
  #     "ansible_python_interpreter=/usr/bin/python3",  # Use python3
  #   ], " ")
  #
  #   all_args = [
  #     "all",
  #     "-v",
  #     "-i", inventory,
  #     "-m", "copy",
  #     "-a", copy_args,
  #     "-e", extra_args,
  #     "--private-key=#{private_key}",
  #     "--vault-password-file=#{vault_password_file}"
  #   ]
  #
  #   cmd = "ansible " <> Enum.join(all_args, " ")
  #   Print.info("Forwarding envrc with ansible: #{cmd}")
  #   system!("ansible", all_args)
  # end
  #
  # defp inventory_hosts_for_role(role) when is_atom(role) do
  #   roles = Bootleg.Config.Agent.get(:roles)
  #   %{hosts: hosts} = Keyword.fetch!(roles, role)
  #
  #   hosts
  # end
  #
  #
  # # Operations
  #
  #
  # defp ensure_target_env!(args) when is_list(args) do
  #   case List.first(args) do
  #     nil -> halt_with_error("Must specify the target environment.")
  #     target_env -> ensure_deploy_config!(target_env)
  #   end
  # end
  #
  # defp locate_release_tarball!(target_env) do
  #   tarball = dist_path_release_tarball(target_env)
  #
  #   case File.exists?(tarball) do
  #     true -> tarball
  #     false -> halt_with_error("Unable to locate #{tarball}")
  #   end
  # end
  #
  # defp locate_release_envrc(target_env) do
  #   envrc = dist_path_release_envrc(target_env)
  #
  #   case File.exists?(envrc) do
  #     true -> envrc
  #     false -> nil
  #   end
  # end
  #
  # defp dist_path_release_envrc(target_env) do
  #   Path.join([
  #     dist_dir_for_env_ver(target_env),
  #     named_envrc(),
  #   ])
  # end
  #
  # defp dist_dir_for_env_ver(target_env) do
  #   Path.join([@dist_dir, target_env, app_version()])
  # end
  #
  # defp dist_path_release_tarball(target_env) do
  #   Path.join([
  #     dist_dir_for_env_ver(target_env),
  #     named_tarball(),
  #   ])
  # end
  #
  # # Naming, versioning, timestamp..
  #
  # defp named_envrc, do: ".envrc"
  #
  # defp named_tarball(), do: "#{app_name()}.tar.gz"
  #
  # defp timestamp_utc_now() do
  #   # "2017-12-19T17:17:36.134976Z" -> "20171219T171736"
  #   DateTime.utc_now()
  #   |> DateTime.to_iso8601()
  #   |> String.split(".")
  #   |> List.first()
  #   |> String.replace("-", "")
  #   |> String.replace(":", "")
  # end
  #
  # defp app_version do
  #   Mix.Project.get.project[:version]
  # end
  #
  #
  # # Helpers
  #
  # defp halt_with_error(message) when is_binary(message) do
  #   Print.error(message)
  #   System.halt(1)
  # end
end
