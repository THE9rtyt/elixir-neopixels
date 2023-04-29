defmodule NeopixelTest do
  use ExUnit.Case
  doctest Neopixel

  test "greets the world" do
    assert Neopixel.hello() == :world
  end
end
