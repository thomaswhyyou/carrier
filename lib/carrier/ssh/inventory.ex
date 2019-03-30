defmodule Carrier.SSH.Inventory do
  @enforce_keys [:hosts]
  defstruct [:hosts, :options]
end
