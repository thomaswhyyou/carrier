defmodule Carrier.Build do
  require Logger

  import Kitch.SystemUtil, only: [halt_with_error: 1, sys_cmd!: 2]
  import Carrier.Global, only: [
    ensure_target_env!: 1,
    release_tarball_dist_path: 1,
    release_envrc_dist_path: 1,
    release_dist_dir: 1,
    root_work_dir: 0,
    root_envrc_dir: 0,
    app_version: 0,
    app_name: 0,
  ]

  # TODO:
  # add hooks, :before_build, :after_build
  # configure webpack?

  def build(args) do
    ensure_docker!()

    dockerfile = ensure_dockerfile()
    target_env = ensure_target_env!(args)

    try do
      ensure_work_dir!()
      before_build()
      do_build(target_env, dockerfile)
      after_build()
    after
      cleanup_work_dir!()
    end
  end

  defp ensure_docker!() do
    try do
      sys_cmd!("type", ["docker"])
    rescue
      _ -> halt_with_error("`docker` command not found, please install Docker first.")
    end
  end

  defp ensure_dockerfile() do
    dockerfile = Application.get_env(:carrier, :dockerfile)

    if dockerfile && File.exists?(dockerfile) do
      dockerfile
    else
      Logger.warn("No :dockerfile config was given, falling back to a default for prod.")
      fallback_dockerfile()
    end
  end

  defp fallback_dockerfile() do
    Application.app_dir(:carrier, Path.join("priv", "Dockerfile.build"))
  end

  defp before_build() do
    # add :before_build hook
    # TODO: frontend build
  end

  defp after_build() do
    # add :after_build hook
  end

  defp do_build(target_env, dockerfile) do
    Logger.info("Preparing to build a release..")
    copy_over_setup_files!()
    copy_over_envrc_file!(target_env)
    ensure_release_dist_dir!(target_env)

    image_name = "#{app_name()}:build"
    cid = "carrier-#{UUID.uuid4()}"

    Logger.info("Building a release inside image: #{image_name}")
    docker(:build, dockerfile, image_name, [])

    Logger.info("Copying a release from: #{cid}")
    docker(:create, cid, image_name)

    # TODO: Below are hardcoded into Dockerfile.build
    release = "_build/prod/rel/#{app_name()}/releases/#{app_version()}/#{app_name()}.tar.gz"
    source = Path.join("/opt/app/", release)
    dest = release_tarball_dist_path(target_env)
    docker(:cp, cid, source, dest)
    docker(:rm, cid)

    Logger.info("Finished building a release: #{dest}")
  end

  defp copy_over_setup_files!() do
    # Should happen before the actual build, used as a cache mechanism
    # for docker for elixir deps.
    [
      Path.wildcard("./config/"),
      Path.wildcard("./mix.exs"),
      Path.wildcard("./mix.lock"),
    ]
    |> List.flatten()
    |> Enum.each(fn f ->
      dest = Path.join(root_work_dir(), f)
      dest |> Path.dirname() |> File.mkdir_p()
      File.cp_r!(f, dest)
    end)
  end

  defp copy_over_envrc_file!(target_env) do
    envrc = Path.join(root_envrc_dir(), "#{target_env}.toml")

    if File.exists?(envrc) do
      dest = release_envrc_dist_path(target_env)
      File.cp!(envrc, dest)
    end
  end

  defp ensure_release_dist_dir!(target_env) do
    target_env |> release_dist_dir() |> File.mkdir_p!()
  end

  defp docker(:cp, cid, source, dest) do
    sys_cmd!("docker", ["cp", "#{cid}:#{source}", dest])
  end

  defp docker(:build, dockerfile, tag, args) do
    # TODO: Currently Dockerfile is harcoded to build for production. Maybe
    # change it to eex template to take target build env, copy it into
    # carrier folder and use that instead?
    sys_cmd!("docker", ["build", "-f", dockerfile, "-t", tag] ++ args ++ ["."])
  end

  defp docker(:create, name, image) do
    sys_cmd!("docker", ["create", "--name", name, image])
  end

  defp docker(:rm, cid) do
    sys_cmd!("docker", ["rm", "-f", cid])
  end

  defp ensure_work_dir!(),
    do: File.mkdir_p!(root_work_dir())

  defp cleanup_work_dir!(),
    do: File.rm_rf!(root_work_dir())
end
