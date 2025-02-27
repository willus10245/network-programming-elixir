defmodule RedisClientNoQueue do
  alias RedisClient.RESP
  require Logger
  use GenServer

  defstruct [:host, :port, :socket, :caller_monitor]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @spec command(GenServer.server(), [String.t()]) :: {:ok, term()} | {:error, term()}
  def command(client, command) do
    case GenServer.call(client, :checkout) do
      {:ok, socket} ->
        result =
          with :ok <- :gen_tcp.send(socket, RESP.encode(command)),
               {:ok, data} <- receive_response(socket, &RESP.decode/1) do
            {:ok, data}
          else
            {:error, reason} -> {:error, reason}
          end

        GenServer.call(client, :checkin)
        result

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp receive_response(socket, continuation) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} ->
        case continuation.(data) do
          {:ok, response, _rest = ""} ->
            {:ok, response}

          {:continuation, new_continuation} ->
            receive_response(socket, new_continuation)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def init(opts) do
    initial_state = %__MODULE__{
      host: Keyword.fetch!(opts, :host),
      port: Keyword.fetch!(opts, :port)
    }

    {:ok, initial_state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, %__MODULE__{} = state) do
    tcp_opts = [:binary, active: :once]

    case :gen_tcp.connect(state.host, state.port, tcp_opts, 5_000) do
      {:ok, socket} ->
        {:noreply, %__MODULE__{state | socket: socket}}

      {:error, reason} ->
        Logger.error("Failed to connect: #{:inet.format_error(reason)}")
        Process.send_after(self(), :reconnect, 1_000)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call(request, from, state)

  def handle_call(:checkout, _from, %__MODULE__{socket: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:checkout, {pid, _ref}, %__MODULE__{} = state) do
    caller_monitor = Process.monitor(pid)
    :ok = :inet.setopts(state.socket, active: false)
    state = %__MODULE__{state | caller_monitor: caller_monitor}
    {:reply, {:ok, state.socket}, state}
  end

  def handle_call(:checkin, _from, %__MODULE__{} = state) do
    Process.demonitor(state.caller_monitor, [:flush])
    :ok = :inet.setopts(state.socket, active: :once)
    {:reply, :ok, %__MODULE__{state | caller_monitor: nil}}
  end

  @impl true
  def handle_info(message, state)

  def handle_info({:tcp_closed, socket}, %__MODULE__{socket: socket} = state) do
    Process.send_after(self(), :reconnect, 1_000)
    {:noreply, %__MODULE__{state | socket: nil}}
  end

  def handle_info({:tcp_error, socket, _reason}, %__MODULE__{socket: socket} = state) do
    Process.send_after(self(), :reconnect, 1_000)
    {:noreply, %__MODULE__{state | socket: nil}}
  end

  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  def handle_info({:DOWN, ref, _, _}, %__MODULE__{caller_monitor: ref} = state) do
    :ok = :inet.setopts(state.socket, active: :once)
    {:noreply, %__MODULE__{state | caller_monitor: nil}}
  end
end
