defmodule RedisClient.StateMachinePool do
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    registry_name = registry_name(name)

    client_specs =
      for index <- 1..Keyword.fetch!(opts, :pool_size) do
        child_opts = Keyword.put(opts, :registry_name, registry_name)

        %{
          id: {:redis, index},
          start: {RedisClient.StateMachine, :start_link, [child_opts]}
        }
      end

    children = [
      {Registry, keys: :duplicate, name: registry_name},
      %{
        id: :clients_supervisor,
        start: {
          Supervisor,
          :start_link,
          [client_specs, [strategy: :one_for_one]]
        }
      }
    ]

    Supervisor.start_link(children, strategy: :rest_for_one, name: name)
  end

  @spec command(:atom, [String.t()]) :: {:ok, term()} | {:error, term()}
  def command(pool_name, command) do
    case Registry.lookup(registry_name(pool_name), :client) do
      [] ->
        {:error, :no_connections_available}

      pids ->
        {pid, _value} = Enum.random(pids)
        RedisClient.StateMachine.command(pid, command)
    end
  end

  defp registry_name(pool_name) do
    Module.concat(pool_name, Registry)
  end
end
