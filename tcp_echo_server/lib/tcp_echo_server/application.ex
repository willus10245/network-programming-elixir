defmodule TCPEchoServer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: TCPEchoServer.Worker.start_link(arg)
      {TCPEchoServer.Acceptor, port: 4000}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TCPEchoServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
