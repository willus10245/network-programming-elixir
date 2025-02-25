defmodule RedisClientTest do
  use ExUnit.Case
  doctest RedisClient

  test "greets the world" do
    assert RedisClient.hello() == :world
  end
end
