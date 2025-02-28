defmodule Chat.AcceptorPool.Acceptor do
  use Task, restart: :transient

  alias Chat.AcceptorPool.ConnectionSupervisor

  require Logger

  @spec start_link(:gen_tcp.socket()) :: {:ok, pid()}
  def start_link(listen_socket) do
    Task.start_link(__MODULE__, :__accept_loop__, [listen_socket])
  end

  @doc false
  def __accept_loop__(listen_socket) do
    case :ssl.transport_accept(listen_socket, 2_000) do
      {:ok, socket} ->
        Logger.debug("Accepted TLS connection")
        {:ok, pid} = ConnectionSupervisor.start_connection(socket)
        :ok = :ssl.controlling_process(socket, pid)
        __accept_loop__(listen_socket)

      {:error, :timeout} ->
        __accept_loop__(listen_socket)

      {:error, reason} ->
        Logger.error("Error in TCP accept: #{:inet.format_error(reason)}")
        :error
    end
  end
end
