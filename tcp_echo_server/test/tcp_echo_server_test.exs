defmodule TCPEchoServerTest do
  use ExUnit.Case
  doctest TCPEchoServer

  test "greets the world" do
    assert TCPEchoServer.hello() == :world
  end
end
