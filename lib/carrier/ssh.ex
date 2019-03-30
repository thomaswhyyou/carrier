defmodule Carrier.SSH do
  @moduledoc """
  Pretty much copied over from Bootleg.SSH: https://github.com/labzero/bootleg
  """

  alias SSHKit.Context
  alias SSHKit.Host, as: SSHKitHost
  alias SSHKit.SSH, as: SSHKitSSH
  alias Carrier.SSH.{Fmt, SSHError, Inventory}

  @doc """
  NOTE(tyu): Modified from the original Bootleg implmentation, to work with
  Inventory and SSHKit.Host directly.
  """
  def init(%{inventory: inventory} = config) do
    inventory = struct(Inventory, inventory)
    options = Map.get(config, :options, [])

    init(inventory, options)
  end

  def init(%Inventory{} = inventory, options) do
    inventory
    |> to_sshkit_hosts()
    |> init(options)
  end

  def init(hosts, options) do
    workspace = Keyword.get(options, :workspace)
    create_workspace = Keyword.get(options, :create_workspace, true)
    working_directory = Keyword.get(options, :cd)

    context_override =
      options
      |> Keyword.get(:context, [])
      |> Enum.into(%{})

    :ssh.start()

    hosts
    |> List.wrap()
    |> Enum.map(&ssh_host_options/1)
    |> SSHKit.context()
    |> prepare_remote_env(options)
    |> validate_workspace(workspace, create_workspace)
    |> working_directory(working_directory)
    |> apply_context(context_override, workspace)
  end

  @doc """
  NOTE(tyu): Added for new init/2
  """
  def to_sshkit_hosts(%{hosts: hosts} = inventory) when is_list(hosts) and length(hosts) > 0 do
    defaults = Map.get(inventory, :options, [])

    hosts
    |> List.wrap()
    |> Enum.map(fn host -> SSHKit.host(host, defaults) end)
  end

  @doc """
  NOTE(tyu): Modified to work directly with SSHKit.Host
  """
  def ssh_host_options(%SSHKitHost{} = ssh_host) do
    %SSHKitHost{ssh_host | options: ssh_opts(ssh_host.options)}
  end

  def apply_context(%Context{} = base_context, %{} = overrides, _workspace)
      when overrides == %{},
      do: base_context

  def apply_context(%Context{} = base_context, %{path: path} = overrides, workspace)
      when not is_nil(workspace) do
    Fmt.warn(
      "Warning: when setting a context path (#{path}), workspace (#{workspace}) is ignored."
    )

    struct(base_context, overrides)
  end

  def apply_context(%Context{} = base_context, %{} = overrides, _workspace),
    do: struct(base_context, overrides)

  def run(context, cmd) do
    cmd = Context.build(context, cmd)

    run = fn host ->
      Fmt.puts_send(host, cmd)

      conn =
        case SSHKitSSH.connect(host.name, host.options) do
          {:ok, conn} -> conn
          {:error, err} -> raise SSHError, [err, host]
        end

      conn
      |> SSHKitSSH.run(cmd, fun: &capture(&1, &2, host), acc: {:cont, {[], nil, %{}}})
      |> Tuple.append(host)
    end

    Enum.map(context.hosts, run)
  end

  def run!(context, command)

  def run!(context, commands) when is_list(commands) do
    Enum.map(commands, fn c -> run!(context, c) end)
  end

  def run!(context, command) do
    context
    |> run(command)
    |> Enum.map(&run_result(&1, command))
  end

  defp run_result({:ok, _, 0, _} = result, _), do: result

  defp run_result({:ok, output, status, host}, command) do
    raise SSHError, [command, output, status, host]
  end

  defp validate_workspace(context, workspace, create_workspace)

  defp validate_workspace(context, nil, _) do
    run!(context, "true")
    context
  end

  defp validate_workspace(context, workspace, false) do
    run!(context, "test -d #{workspace}")
    SSHKit.path(context, workspace)
  end

  defp validate_workspace(context, workspace, true) do
    run!(context, "mkdir -p #{workspace}")
    SSHKit.path(context, workspace)
  end

  defp working_directory(context, path) when path == "." or path == false or is_nil(path) do
    context
  end

  defp working_directory(context, path) do
    case Path.type(path) do
      :absolute -> %Context{context | path: path}
      _ -> %Context{context | path: Path.join(context.path, path)}
    end
  end

  defp prepare_remote_env(context, options) do
    env = Keyword.get(options, :env, %{})

    case Keyword.get(options, :replace_os_vars, true) do
      true -> SSHKit.env(context, Map.merge(%{REPLACE_OS_VARS: true}, env))
      _ -> SSHKit.env(context, env)
    end
  end

  @last_new_line ~r/\A(?<bulk>.*)((?<newline>\n)(?<remainder>[^\n]*))?\z/msU

  defp split_last_line(data) do
    %{"bulk" => bulk, "newline" => newline, "remainder" => remainder} =
      Regex.named_captures(@last_new_line, data)

    if newline == "\n" do
      {bulk <> "\n", remainder}
    else
      {"", bulk}
    end
  end

  defp buffer_complete_lines(data, device, buffer, partial_buffer) do
    partial_line = partial_buffer[device] || ""
    {bulk, remainder} = split_last_line(partial_line <> data)
    new_partial_buffer = Map.put(partial_buffer, device, remainder)

    if bulk == "" do
      {buffer, new_partial_buffer, bulk}
    else
      {[{device, bulk} | buffer], new_partial_buffer, bulk}
    end
  end

  defp empty_partial_buffer(buffer, partial_buffer) do
    remainders = Enum.filter(partial_buffer, fn {_, value} -> value && value != "" end)
    remainders ++ buffer
  end

  defp capture(message, {buffer, status, partial_buffer} = state, host) do
    next =
      case message do
        {:data, _, 0, data} ->
          {buffer, partial_buffer, data} =
            buffer_complete_lines(data, :stdout, buffer, partial_buffer)

          Fmt.puts_recv(host, String.trim_trailing(data))
          {buffer, status, partial_buffer}

        {:data, _, 1, data} ->
          {buffer, partial_buffer, _} =
            buffer_complete_lines(data, :stderr, buffer, partial_buffer)

          {buffer, status, partial_buffer}

        {:exit_status, _, code} ->
          {buffer, code, partial_buffer}

        {:closed, _} ->
          {:ok, Enum.reverse(empty_partial_buffer(buffer, partial_buffer)), status}

        _ ->
          state
      end

    {:cont, next}
  end

  def download(conn, remote_path, local_path) do
    Fmt.puts_download(conn, remote_path, local_path)

    case SSHKit.download(conn, remote_path, as: local_path, recursive: true) do
      [:ok | _] -> :ok
      [] -> :ok
      [{_, msg} | _] -> raise "SCP download error: #{msg}"
    end
  end

  def upload(conn, local_path, remote_path) do
    Fmt.puts_upload(conn, local_path, remote_path)

    case SSHKit.upload(conn, local_path, as: remote_path, recursive: true) do
      [:ok | _] -> :ok
      [] -> :ok
      [{_, msg} | _] -> raise "SCP upload error #{msg}"
    end
  end

  def ssh_opts(options) do
    opts = Enum.map(options, &ssh_opt/1)

    opts
    |> Enum.map(&ssh_transform_opt(&1, opts))
    |> List.flatten()
    |> Enum.filter(&ssh_option?/1)
  end

  def ssh_opt({_, nil}), do: []

  def ssh_opt({:passphrase_provider, {module, fun}})
      when is_atom(module) and is_atom(fun) do
    case function_exported?(module, fun, 0) do
      false ->
        []

      true ->
        module
        |> apply(fun, [])
        |> parse_passphrase()
    end
  end

  def ssh_opt({:passphrase_provider, {command, args}})
      when is_binary(command) and is_list(args) do
    case System.cmd(command, args) do
      {v, 0} ->
        v
        |> String.trim_trailing("\n")
        |> parse_passphrase()

      _ ->
        []
    end
  end

  def ssh_opt({:passphrase_provider, fun}) when is_function(fun, 0) do
    fun
    |> apply([])
    |> parse_passphrase()
  end

  def ssh_opt(option), do: option

  defp parse_passphrase(v) when is_binary(v) and byte_size(v) > 0, do: {:passphrase, v}
  defp parse_passphrase(_v), do: []

  defp ssh_transform_opt({:identity, identity_file}, options) do
    identity = File.open!(Path.expand(identity_file))

    key_cb =
      options
      |> Enum.map(&ssh_opt/1)
      |> Enum.filter(&ssh_key_cb_option?/1)
      |> Keyword.put(:identity, identity)
      |> SSHClientKeyAPI.with_options()

    [{:key_cb, key_cb}]
  end

  defp ssh_transform_opt(option, _), do: option

  @ssh_options ~w(user password port key_cb auth_methods connection_timeout id_string
    idle_time user_dir timeout connection_timeout identity quiet_mode
    silently_accept_hosts known_hosts)a
  @doc """
  Return a list of options which are specific to SSH
  """
  def ssh_options do
    Application.get_env(:carrier, :ssh_options, @ssh_options)
  end

  def ssh_option?({k, _v}) do
    Enum.member?(ssh_options(), k) == true
  end

  def ssh_option?(_), do: false

  @ssh_key_cb_options ~w(silently_accept_hosts passphrase known_hosts)a
  @doc """
  Return a list of options which may be passed through to the public_key callback
  """
  def ssh_key_cb_options do
    Application.get_env(:carrier, :ssh_key_cb_options, @ssh_key_cb_options)
  end

  defp ssh_key_cb_option?({k, _v}) do
    Enum.member?(ssh_key_cb_options(), k) == true
  end

  defp ssh_key_cb_option?(_), do: false

  @spec merge_run_results(list, list) :: list
  def merge_run_results(new, []) do
    new
  end

  def merge_run_results([], orig) do
    orig
  end

  def merge_run_results(new, orig) when is_list(orig) do
    delta = length(new) - length(orig)
    entries = List.duplicate([], abs(delta))

    {new, orig} =
      if delta > 0 do
        {new, orig ++ entries}
      else
        {new ++ entries, orig}
      end

    new
    |> Enum.zip(orig)
    |> Enum.map(fn {n, o} ->
      List.wrap(o) ++ List.wrap(n)
    end)
  end
end
