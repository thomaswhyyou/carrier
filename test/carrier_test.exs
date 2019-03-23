defmodule CarrierTest do
  use ExUnit.Case
  doctest Carrier

  test "greets the world" do
    assert Carrier.hello() == :world
  end
end
