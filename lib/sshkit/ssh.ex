defmodule SSHKit.SSH do
  @moduledoc ~S"""
  Provides convenience functions for working with SSH connections
  and executing commands on remote hosts.

  ## Examples

  ```
  {:ok, conn} = SSHKit.SSH.connect("eg.io", user: "me")

  log = fn msg ->
    case msg do
      {:data, _, 0, data} -> IO.write(data)
      {:data, _, 1, data} -> IO.write([IO.ANSI.red, data, IO.ANSI.reset])
    end

    msg
  end

  :ok = SSHKit.SSH.stream(conn, "uptime")
  |> Stream.map(log)
  |> TODO: Refine example

  :ok = SSHKit.SSH.close(conn)
  ```
  """

  alias SSHKit.SSH.Connection
  alias SSHKit.SSH.Channel

  @doc """
  Establishes a connection to an SSH server.

  Uses `SSHKit.SSH.Connection.open/2` to open a connection.

  ## Example

  ```
  {:ok, conn} = SSHKit.SSH.connect("eg.io", port: 2222, user: "me", timeout: 1000)
  ```
  """
  def connect(host, options \\ []) do
    Connection.open(host, options)
  end

  @doc """
  Closes an SSH connection.

  Uses `SSHKit.SSH.Connection.close/1` to close the connection.

  ## Example

  ```
  :ok = SSHKit.SSH.close(conn)
  ```
  """
  def close(connection) do
    Connection.close(connection)
  end

  @doc """
  Executes a command on the remote.

  Returns a channel stream, which will yield all channel messages and which you
  can send messages into (the stream implements the Enumerable and Collectable
  protocols).

  ## Example

  ```
  SSHKit.SSH.stream(conn, "uptime")
  |> Stream.reduce...

  TODO: Refine example
  ```
  """
  def stream(connection, command \\ nil, options \\ []) do
    case Channel.open(connection, options) do
      {:ok, channel} -> exec(channel, command, options) |> do_stream(options)
      other -> other
    end
  end

  defp do_stream(channel, options) do
    Channel.Stream.__build__(channel, options)
  end

  defp exec(channel, nil, _) do
    channel
  end

  defp exec(channel, command, options) do
    timeout = Keyword.get(options, :timeout, :infinity)
    case Channel.exec(channel, command, timeout) do
      :failure -> {:error, :failure}
      :success -> channel
      other -> other
    end
  end
end
