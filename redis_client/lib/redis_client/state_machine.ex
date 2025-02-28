defmodule RedisClient.StateMachine do
  @behaviour :gen_statem

  alias RedisClient.RESP

  require Logger

  defstruct [:host, :port, :socket, :continuation, queue: :queue.new()]

  @spec start_link(keyword()) :: :gen_statem.start_ret()
  def start_link(opts) do
    :gen_statem.start_link(__MODULE__, opts, _gen_statem_options = [])
  end

  @spec command(pid(), [String.t()], timeout()) :: {:ok, term()} | {:error, term()}
  def command(pid, command, timeout \\ 5000) do
    :gen_statem.call(pid, {:command, command}, timeout)
  end

  @impl :gen_statem
  def callback_mode, do: [:state_functions, :state_enter]

  @impl :gen_statem
  def init(opts) do
    if registry = opts[:registry_name] do
      {:ok, _} = Registry.register(registry, :client, :no_value)
    end

    data = %__MODULE__{
      host: Keyword.fetch!(opts, :host),
      port: Keyword.fetch!(opts, :port)
    }

    actions = [{:next_event, :internal, :connect}]
    {:ok, :disconnected, data, actions}
  end

  # Connected state

  def connected({:call, from}, {:command, command}, data) do
    :ok = :gen_tcp.send(data.socket, RESP.encode(command))
    data = update_in(data.queue, &:queue.in(from, &1))
    {:keep_state, data}
  end

  def connectd(:enter, _old_state = :disconnected, _data) do
    actions = [{{:timeout, :reconnect}, :cancel}]
    {:keep_state_and_data, actions}
  end

  # Disconnected state

  @backoff_time 1_000

  def disconnected({:call, from}, {:command, _command}, _data) do
    {:keep_state_and_data, [{:reply, from, {:error, :not_connected}}]}
  end

  def disconnected(:internal, :connect, data) do
    opts = [:binary, active: :once]

    case :gen_tcp.connect(data.host, data.port, opts, 5_000) do
      {:ok, socket} ->
        data = %__MODULE__{data | socket: socket}
        {:next_state, :connected, data}

      {:error, reason} ->
        Logger.error("Failed to connect: #{:inet.format_error(reason)}")
        timer_action = {{:timeout, :reconnect}, @backoff_time, nil}
        {:keep_state_and_data, [timer_action]}
    end
  end

  def disconnected({:timeout, :reconnect}, nil, _data) do
    actions = [{:next_event, :internal, :connect}]
    {:keep_state_and_data, actions}
  end
end
