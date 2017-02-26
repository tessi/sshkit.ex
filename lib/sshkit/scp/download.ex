defmodule SSHKit.SCP.Download do
  alias SSHKit.SCP.Command

  @doc """
  Downloads a file or directory from a remote host.

  ## Options

  * `:verbose` - let the remote scp process be verbose, default `false`
  * `:recursive` - set to `true` for copying directories, default `false`
  * `:preserve` - preserve timestamps, default `false`
  * `:timeout` - timeout in milliseconds, default `:infinity`

  ## Example

  ```
  :ok = SSHKit.SCP.Download.transfer(conn, '/home/code/sshkit', 'downloads', recursive: true)
  ```
  """
  def transfer(connection, remote, local, options \\ []) do
    recursive = Keyword.get(options, :recursive, false)
    local = Path.expand(local)

    if recursive && !File.dir?(local) do
      :ok = File.mkdir!(local)
    end

    start(connection, remote, local, options)
  end

  defp start(connection, remote, local, options) do
    timeout = Keyword.get(options, :timeout, :infinity)

    command = Command.build(:download, remote, options)

    ini = {:next, <<>>, Path.dirname(local), []}

    handler = fn message, state ->
      IO.inspect(message)
      IO.inspect(state)

      case message do
        {:data, _, 0, <<1, msg :: binary>>} -> warning(options, state, msg)
        {:data, _, 0, <<2, msg :: binary>>} -> fatal(options, state, msg)
        {:data, _, 0, msg} ->
          case state do
            {:next, buffer, cwd, stack} -> next(options, buffer <> msg, cwd, stack)
            # {:read, buffer, cwd, stack} -> read()
            {:done, status} -> done(options, status)
            {:warning, state, buffer} -> warning(options, state, buffer <> msg)
            {:fatal, state, buffer} -> fatal(options, state, buffer <> msg)
          end
        {:exit_status, _, status} -> exited(options, status, elem(state, 2), elem(state, 3))
        {:eof, _} -> cont(state)
        {:closed, _} -> cont(state)
      end
    end

    SSHKit.SSH.run(connection, command, timeout: timeout, acc: {:cont, <<0>>, ini}, fun: handler)
  end

  defp next(options, buffer, cwd, stack) do
    if String.last(buffer) == "\n" do
      case parse(buffer) do
        {"T", mtime, atime} -> time(options, cwd, stack, mtime, atime)
        {"C", mode, len, name} -> regular(options, cwd, stack, mode, len, name)
        {"D", mode, name} -> directory(options, cwd, stack, mode, name)
        {"E"} -> up(options, cwd, stack)
      end
    else
      {:cont, {:next, buffer, cwd, stack}}
    end
  end

  defp time(_, cwd, stack, mtime, atime) do
    IO.puts("T: #{mtime} #{atime}")
    {:cont, <<0>>, {:next, <<>>, cwd, stack}}
  end

  defp directory(_, cwd, stack, mode, name) do
    IO.puts("D: #{mode} #{name}")
    # :ok = File.mkdir!()
    {:cont, <<0>>, {:next, <<>>, Path.join(cwd, name), stack}}
  end

  defp regular(_, cwd, stack, mode, length, name) do
    IO.puts("C: #{mode} #{length} #{name}")
    {:cont, <<0>>, {:next, <<>>, cwd, stack}}
  end

  defp data(_) do
    #
    {:cont, <<0>>, {:next, <<>>, cwd, stack}}
  end

  defp up(_, cwd, stack) do
    IO.puts("E")
    {:cont, <<0>>, {:next, <<>>, Path.dirname(cwd), stack}}
  end

  defp exited(_, status, cwd, stack) do
    {:cont, {:done, status}}
  end

  defp done(_, 0) do
    {:cont, :ok}
  end

  defp done(_, status) do
    {:cont, {:error, "SCP exited with a non-zero exit code (#{status})"}}
  end

  defp cont(state) do
    {:cont, state}
  end

  defp warning(options, state, buffer) do
    error(options, :warning, state, buffer)
  end

  defp fatal(options, state, buffer) do
    error(options, :fatal, state, buffer)
  end

  defp error(_, type, state, buffer) do
    if String.last(buffer) == "\n" do
      {:halt, {:error, String.trim(buffer)}}
    else
      {:cont, {type, state, buffer}}
    end
  end

  @dfmt ~r/\A((C|D)([0-7]{4}) (0|[1-9]\d*) (.+)|(E)|(T)(0|[1-9]\d*) (0|[1-9]\d*) (0|[1-9]\d*) (0|[1-9]\d*))\n\z/

  defp parse(value) do
    parts = case Regex.run(@dfmt, value, capture: :all_but_first) do
      nil -> nil
      res -> Enum.drop(res, 1)
    end

    case parts do
      ["T", mtime, mtms, atime, atms] -> {"T", dec(mtime), dec(mtms), dec(atime), dec(atms)}
      ["C", mode, len, name] -> {"C", oct(mode), dec(len), name}
      ["D", mode, _, name] -> {"D", oct(mode), name}
      ["E"] -> {"E"}
      nil -> nil
    end
  end

  defp int(value, base), do: String.to_integer(value, base)
  defp dec(value), do: int(value, 10)
  defp oct(value), do: int(value, 8)
end
