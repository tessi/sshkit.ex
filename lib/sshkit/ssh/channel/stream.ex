defmodule SSHKit.SSH.Channel.Stream do
  defstruct [channel: nil, options: []]

  @doc false
  def __build__(channel, options) do
    %SSHKit.SSH.Channel.Stream{channel: channel, options: options}
  end

  defimpl Collectable do
    def into(stream = %{channel: channel, options: options}) do
      {:ok, into(stream, channel, options)}
    end

    defp into(stream, channel, options) do
      timeout = Keyword.get(options, :timeout, :infinity)

      fn
        :ok, {:cont, message} ->
          case message do
            {type, data} -> :ok = Channel.send(channel, type, data, timeout)
            :eof -> :ok = Channel.eof(channel)
            data -> :ok = Channel.send(channel, data, timeout)
          end
        :ok, _ -> stream
      end
    end
  end

  defimpl Enumerable do
    def reduce(stream = %{channel: channel, options: options}, acc, fun) do
      ref = channel.connection.ref
      id = channel.id

      timeout = Keyword.get(options, :timeout, :infinity)

      start = fn -> channel end

      next = fn channel ->
        receive do
          {:ssh_cm, ^ref, msg} when elem(msg, 1) == id ->
            if elem(msg, 0) == :closed do
              {:halt, channel}
            else
              {[msg], channel}
            end
        after
          timeout ->
            raise "timeout" # read timeout
        end
      end

      fin = &(&1)

      Stream.resource(start, next, fin).(acc, fun)
    end

    def count(_) do
      {:error, __MODULE__}
    end

    def member?(_, _) do
      {:error, __MODULE__}
    end
  end
end
