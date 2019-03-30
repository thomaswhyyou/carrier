defmodule Carrier.SSH.SSHError do
  @moduledoc """
  Pretty much copied over from Bootleg: https://github.com/labzero/bootleg
  """

  defexception [:message, :status, :output, :host]

  def exception([cmd, output, status, host]) do
    msg =
      "Command exited on #{host.name} with non-zero status (#{status})\n" <>
        format("cmd", cmd) <> output_format(output)

    %__MODULE__{message: msg, status: status, output: output, host: host}
  end

  def exception([err, host]) do
    msg = "SSHKit returned an internal error on #{host.name}: #{inspect(err)}"
    %__MODULE__{message: msg, status: err, host: host}
  end

  @padding 8
  defp format(key, value) do
    String.pad_leading(key, @padding) <> ": " <> indent(String.trim_trailing(value)) <> "\n"
  end

  defp indent(str) do
    String.replace(str, "\n", "\n" <> String.duplicate(" ", @padding + 2))
  end

  defp output_format(output) do
    output
    |> Enum.map(fn {type, msg} -> format(Atom.to_string(type), msg) end)
    |> Enum.join()
  end
end
