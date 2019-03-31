defmodule Carrier.Global do
  require Logger

  @root_dist_dir "./_dist"
  @root_work_dir "./_carrier"
  @root_envrc_dir "./config/envrc"
  @root_deploy_config_dir "./config/deploy"
  @remote_releases_dir "./releases"

  @accepted_args [
    target_env: :string,
    target_release: :string,
    remote_command: :string,
  ]

  # How release artifacts will be named

  def envrc_filename(), do: "config.toml"

  def tarball_filename(), do: "#{app_name()}.tar.gz"

  # Local sources

  def root_dist_dir(), do: @root_dist_dir

  def root_work_dir(), do: @root_work_dir

  def root_envrc_dir(), do: @root_envrc_dir

  def release_dist_dir(target_env) when is_binary(target_env) do
    Path.join([root_dist_dir(), target_env, app_version()])
  end

  def release_envrc_dist_path(target_env) do
    Path.join([release_dist_dir(target_env), envrc_filename()])
  end

  def release_tarball_dist_path(target_env) do
    Path.join([release_dist_dir(target_env), tarball_filename()])
  end

  # Remote destination

  def remote_releases_dir(), do: @remote_releases_dir

  def exec_current_app(), do: "./current/bin/#{app_name()}"

  def exec_current_app(cmd), do: "#{exec_current_app()} #{cmd}"

  # Checks and balances

  def ensure_target_env!(args) when is_list(args) do
    {switches, _} = parse_args!(args)

    case Keyword.get(switches, :target_env) do
      nil ->
        halt_with_error("Must specify a target environment with `--target-env`")

      env when env in ["dev", "prod"] ->
        env

      env ->
        halt_with_error("Unknown target environment: '#{env}'")
    end
  end

  def ensure_deploy_config!(target_env) do
    config_path = deploy_config_path(target_env)

    if not File.exists?(config_path) do
      halt_with_error("Unable to locate a deploy config file: #{config_path}")
    end

    {config, _} = Code.eval_file(config_path)

    if get_in(config, [:options, :workspace]) == nil do
      halt_with_error("Missing deploy config :options, :workspace.")
    end

    if get_in(config, [:options, :vault_password_file]) == nil do
      halt_with_error("Missing deploy config :options, :vault_password_file.")
    end

    config
  end

  def deploy_config_path(target_env) do
    filepath = Path.join([@root_deploy_config_dir, target_env])

    "#{filepath}.exs"
  end

  def parse_args!(args) do
    result = OptionParser.parse(args, strict: @accepted_args)

    case result do
      {switches, args, []} -> {switches, args}
      {_, _, unknown} -> raise(ArgumentError, message: "Unknown argument(s) given: #{inspect(unknown)}")
    end
  end

  # Helpers

  def app_version() do
    Mix.Project.get.project[:version]
  end

  def app_name() do
    release_name_from_cwd =
      File.cwd!
      |> Path.basename
      |> String.replace("-", "_")

    Mix.Project.get.project[:app] || release_name_from_cwd
  end

  def halt_with_error(message) when is_binary(message) do
    Logger.error(message)
    # Otherwise quits even before error message?
    :timer.sleep(100)
    System.halt(1)
  end

  def sys_cmd(cmd, args) do
    System.cmd(cmd, args, into: IO.stream(:stdio, :line))
  end

  def sys_cmd!(cmd, args) do
    {_, 0} = sys_cmd(cmd, args)
  end
end
