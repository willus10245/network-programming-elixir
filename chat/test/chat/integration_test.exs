defmodule Chat.IntegrationTest do
  use ExUnit.Case, async: true

  import Chat.Protocol

  alias Chat.Message.{Broadcast, Register}

  test "server closes connection if client sends register message twice" do
    {:ok, client} = :gen_tcp.connect(~c"localhost", 4000, [:binary])
    encoded_message = encode_message(%Register{username: "scott"})
    :ok = :gen_tcp.send(client, encoded_message)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        :ok = :gen_tcp.send(client, encoded_message)
        assert_receive {:tcp_closed, ^client}, 500
      end)

    assert log =~ "Invalid Register message"
  end

  test "broadcasting messages" do
    client_jerry = connect_user("jerry")
    client_elaine = connect_user("elaine")
    client_kramer = connect_user("kramer")

    # TODO: remove once we'll have "welcome" messages
    Process.sleep(100)

    # Simulate Kramer sending a message
    message_contents = "I’m out there, Jerry. And I’m loving every minute of it!"
    broadcast_message = %Broadcast{from_username: "", contents: message_contents}
    encoded_message = encode_message(broadcast_message)
    :ok = :gen_tcp.send(client_kramer, encoded_message)

    # Assert Kramer doesn't receive a message
    refute_receive {:tcp, ^client_kramer, _data}

    # other clients receive the message
    assert_receive {:tcp, ^client_jerry, data}, 500
    assert {:ok, message, ""} = decode_message(data)
    assert message == %Broadcast{from_username: "kramer", contents: message_contents}

    assert_receive {:tcp, ^client_elaine, data}, 500
    assert {:ok, message, ""} = decode_message(data)
    assert message == %Broadcast{from_username: "kramer", contents: message_contents}
  end

  defp connect_user(username) do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 4000, [:binary])
    register_message = %Register{username: username}
    encoded_message = encode_message(register_message)
    :ok = :gen_tcp.send(socket, encoded_message)
    socket
  end
end
