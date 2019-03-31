defmodule Carrier.Init do
  require Logger

  import Carrier.Global, only: [
    sys_cmd!: 2,
  ]

  @rel_commands_dir "./rel/commands"
  @dest_ansible_dir "./ansible"
  @repo_runner_module "Elixir.Carrier.RepoRun"

  def init(args) do
    init_distillery_release(args)
    copy_over_ansible_playbooks()
    generate_db_commands(["migrate", "rollback", "seed"])
  end

  #
  # Private
  #

  defp init_distillery_release(args) do
    case File.exists?("./rel/config.exs") do
      true -> Logger.warn("Distillery already initialized, skipping..")
      false -> do_init_distillery_release(args)
    end
  end

  defp do_init_distillery_release(args) do
    Logger.info("Initializing Distillery..")
    Mix.Task.run("release.init", args)
  end

  defp copy_over_ansible_playbooks() do
    case File.exists?(@dest_ansible_dir) do
      true -> Logger.warn("Ansible examples already exist, skipping..")
      false -> do_copy_over_ansible_example()
    end
  end

  defp do_copy_over_ansible_example() do
    Logger.info("Copying over ansible examples..")
    ansible_dir = from_priv_dir("ansible")

    File.cp_r!(ansible_dir, @dest_ansible_dir)
  end

  defp generate_db_commands(commands) do
    Enum.each(commands, &write_db_command_executable/1)

    Logger.warn("""
    Make sure to register the generated commands in your release config, for example:

    set commands: [
      "db_migrate": "rel/commands/db_migrate.sh",
      "db_rollback": "rel/commands/db_rollback.sh",
      "db_seed": "rel/commands/db_seed.sh",
    ]
    """)
  end

  defp write_db_command_executable(command) do
    app = Mix.Project.get.project[:app]

    content = """
    #!/bin/sh

    $RELEASE_ROOT_DIR/bin/#{app} command #{@repo_runner_module} #{command}
    """

    executable_path = Path.join(@rel_commands_dir, "db_#{command}.sh")
    Logger.info("Generating db command: #{executable_path}")

    File.mkdir_p!(@rel_commands_dir)
    File.write!(executable_path, content)

    sys_cmd!("chmod", ["+x", executable_path])
  end

  defp from_priv_dir(subpath) when is_binary(subpath) do
    from_priv_dir([subpath])
  end

  defp from_priv_dir(subpaths) when is_list(subpaths) do
    Application.app_dir(:carrier, Path.join([ "priv" | subpaths ]))
  end
end
