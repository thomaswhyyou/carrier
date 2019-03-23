defmodule Carrier.Common do
  import Kitch.SystemUtil, only: [halt_with_error: 1]

  @root_dist_dir "./_dist"
  @root_work_dir "./_carrier"
  @root_envrc_dir "./config/envrc"

  def root_dist_dir(), do: @root_dist_dir

  def root_work_dir(), do: @root_work_dir

  def root_envrc_dir(), do: @root_envrc_dir

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

  def named_envrc(), do: ".envrc"

  def named_tarball(), do: "#{app_name()}.tar.gz"

  def release_dist_dir(target_env) when is_binary(target_env) do
    Path.join([root_dist_dir(), target_env, app_version()])
  end

  def release_envrc_dist_path(target_env) do
    Path.join([release_dist_dir(target_env), named_envrc()])
  end

  def release_tarball_dist_path(target_env) do
    Path.join([release_dist_dir(target_env), named_tarball()])
  end

  def release_envrc_dist_path(target_env) do
    Path.join([release_dist_dir(target_env), named_tarball()])
  end

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

  def parse_args!(args) do
    result = OptionParser.parse(args, strict: [target_env: :string])

    case result do
      {switches, args, []} -> {switches, args}
      {_, _, unknown} -> raise(ArgumentError, message: "Unknown argument(s) given: #{inspect(unknown)}")
    end
  end
end
