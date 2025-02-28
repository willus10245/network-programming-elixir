defmodule Chat.AcceptorPool.Listener do
  use GenServer, restart: :transient

  alias Chat.AcceptorPool.AcceptorSupervisor

  require Logger

  @spec start_link({keyword(), pid()}) :: GenServer.on_start()
  def start_link({opts, supervisor}) do
    GenServer.start_link(__MODULE__, {opts, supervisor})
  end

  @impl true
  def init({opts, supervisor}) do
    port = Keyword.fetch!(opts, :port)

    listen_options = [
      :binary,
      active: :once,
      exit_on_close: false,
      reuseaddr: true,
      cacertfile: Application.app_dir(:chat, "priv/ca.pem"),
      certfile: Application.app_dir(:chat, "priv/server.crt"),
      keyfile: Application.app_dir(:chat, "priv/server.key"),
    ]

    case :ssl.listen(port, listen_options) do
      {:ok, listen_socket} ->
        Logger.info("Started TLS pooled chat server on port #{port}")
        state = {listen_socket, supervisor}
        {:ok, state, {:continue, :start_acceptor_pool}}

      {:error, reason} ->
        {:stop, {:listen_error, reason}}
    end
  end

  @impl true
  def handle_continue(:start_acceptor_pool, {listen_socket, supervisor}) do
    spec = {AcceptorSupervisor, listen_socket: listen_socket}
    {:ok, _} = Supervisor.start_child(supervisor, spec)

    {:noreply, {listen_socket, supervisor}}
  end
end
