defmodule Mix.Tasks.ChatClient do
  use Mix.Task

  import Chat.Protocol

  alias Chat.Message.{Broadcast, Register}

  def run([] = _args) do
    {:ok, socket} =
      :ssl.connect(~c"localhost", 4000, [
        mode: :binary,
        active: :once,
        verify: :verify_peer,
        cacertfile: Application.app_dir(:chat, "priv/ca.pem"),
        certfile: Application.app_dir(:chat, "priv/client.crt"),
        keyfile: Application.app_dir(:chat, "priv/client.key")
      ])

    user = Mix.shell().prompt("Enter your username:") |> String.trim()

    :ok = :ssl.send(socket, encode_message(%Register{username: user}))

    receive_loop(user, socket, spawn_prompt_task(user))
  end

  defp handle_data(data) do
    case decode_message(data) do
      {:ok, %Broadcast{} = message, ""} ->
        IO.puts("\n#{message.from_username}> #{message.contents}")

      _other ->
        Mix.raise(
          "Expected a complete broadcast message and nothing else, " <>
            "got: #{inspect(data)}"
        )
    end
  end

  defp receive_loop(username, socket, %Task{ref: ref} = prompt_task) do
    receive do
      # Task result, which is the contents of the message typed by the user
      {^ref, message} ->
        broadcast = %Broadcast{from_username: "", contents: message}
        :ok = :ssl.send(socket, encode_message(broadcast))
        receive_loop(username, socket, spawn_prompt_task(username))

      {:DOWN, ^ref, _, _, _} ->
        Mix.raise("Prompt task exited unexpectedly")

      {:ssl, ^socket, data} ->
        :ok = :ssl.setopts(socket, active: :once)
        handle_data(data)
        receive_loop(username, socket, prompt_task)

      {:ssl_closed, ^socket} ->
        IO.puts("Server closed the connection")

      {:ssl_error, ^socket, reason} ->
        Mix.raise("TLS error: #{inspect(reason)}")
    end
  end

  defp spawn_prompt_task(username) do
    Task.async(fn -> Mix.shell().prompt("#{username}# ") end)
  end
end
