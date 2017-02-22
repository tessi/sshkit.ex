alias SSHKit.SSH

# Setup

{:ok, conn} = SSH.connect('192.168.99.100', port: 2222, user: 'test', password: 'test', silently_accept_hosts: true, timeout: 2000)

# Test-drive SSH

stream = SSH.stream(conn, 'uptime', timeout: 2000)

IO.inspect(stream)

{output, 0} = Enum.reduce(stream, {[], nil}, fn msg, state = {buffer, status} ->
  IO.inspect([msg, state])

  case msg do
    {:data, _, 0, data} -> {[{:normal, data} | buffer], status}
    {:data, _, 1, data} -> {[{:stderr, data} | buffer], status}
    {:exit_status, _, code} -> {Enum.reverse(buffer), code}
    _ -> state
  end
end)

# IO.inspect(output)

# Clean up

:ok = SSH.close(conn)

nil
