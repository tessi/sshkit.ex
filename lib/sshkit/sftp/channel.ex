defmodule SSHKit.SFTP.Channel do
  alias SSHKit.SFTP.Channel
  alias SSHKit.SSH.Connection
  defstruct [:id, :connection]

  @doc """
  Opens an SFTP channel on an SSH connection.

  On success, returns `{:ok, channel}`, where `channel` is a `Channel` struct.
  Returns `{:error, reason}` if a failure occurs.

  For more details, see [`:ssh_sftp.start_channel/2`](http://erlang.org/doc/man/ssh_sftp.html#start_channel-2).

  ## Options

  * `:timeout` - defaults to `:infinity`
  * `:sftp_vsn` - desired SFTP protocol version

  """

  def open(_, _options \\ [])
  def open(%Connection{ref: ref} = connection, options) do
    case :ssh_sftp.start_channel(ref, options) do
      {:ok, id} -> {:ok, %Channel{connection: connection, id: id}}
      other -> other
    end
  end

  @doc """
  Creates an SSL connection to a given host and opens an SFTP channel on it
  Opens an SFTP channel on an SSH connection.

  On success, returns `{:ok, channel}`, where `channel` is a `Channel` struct.
  Returns `{:error, reason}` if a failure occurs.

  For more details, see [`:ssh_sftp.start_channel/2`](http://erlang.org/doc/man/ssh_sftp.html#start_channel-2).

  ## Options

  * `:port` - SSH port on remote machine
  * `:timeout` - defaults to `:infinity`
  * `:sftp_vsn` - desired SFTP protocol version

  """

  def open(host, options) do
    IO.puts("is_binary")
    case Connection.open(host, options) do
      {:ok, %Connection{} = connection} -> Channel.open(connection, options)
      other -> other
    end
  end
end
