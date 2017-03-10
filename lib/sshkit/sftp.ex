defmodule SSHKit.SFTP do
  alias SSHKit.SFTP.Channel
  
  def upload(%Channel{} = channel, source, remote) when is_binary(source) do
    case File.open(source) do
      {:ok, io} -> upload(channel, io, remote)
      other -> other
    end    
  end

  def upload(%Channel{id: id}, source, remote) do
    case IO.read(source, :all) do
      {:error, err} -> {:error, err}      
      data -> :ssh_sftp.write_file(id, remote, data)
    end        
  end

  def download(%Channel{} = channel, remote, local) when is_binary(local) do
    case File.open(local, [:write]) do
      {:ok, io} -> download(channel, remote, io)
      other -> other
    end    
  end  

  def download(%Channel{id: id}, remote, local)  do
    case :ssh_sftp.read_file(id, remote) do
      {:ok, data} -> IO.write(local, data)
      other -> other
    end
  end
end