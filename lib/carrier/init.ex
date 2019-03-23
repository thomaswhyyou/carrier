defmodule Carrier.Init do
  require Logger

  def init(args) do
    Logger.info("Initializing Distillery..")
    Mix.Task.run("release.init", args)
  end
end
