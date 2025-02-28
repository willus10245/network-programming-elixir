defmodule RedisClient.Pool do
  def start_link(worker_args) do
    pool_args = [worker_module: RedisClientQueued, size: 5]
    :poolboy.start_link(pool_args, worker_args)
  end

  def command(pool, command) do
    :poolboy.transaction(pool, fn client ->
      RedisClientQueued.command(client, command)
    end)
  end
end
