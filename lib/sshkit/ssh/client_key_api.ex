defmodule SSHKit.SSH.ClientKeyApi do
  @moduledoc ~S"""

  Simple wrapper for the Erlang `:ssh_client_key_api behavior`, to
  to make it easier to specify SSH keys and known_hosts files independently of
  any particular users home directory


  It is meant to primarily be used via the convenience function `with_config`:

  `
  cb = SSHKit.SSH.ClientKeyApi.with_config(key_file: "path/to/keyfile", known_hosts_file: "path_to_known_hostsFile", accept_hosts: false)  
  `

  The result can be passed as an option when creating an `SSHKit.SSH.Connection`:

  `
  SSHKit.SSH.connect("example.com", key_cb: cb)
  `

  If more flexibility is needed you can provide options directly when providing your options to `connect`:

  `
  SSHKit.SSH.Connection.open("example.com",
                              key_cb: {
                               SSHKit.SSH.ClientKeyApi, [
                                  key: <IO.device>,
                                  known_hosts: <IO.device>,
                                  accept_hosts: false]})
  `                                  

   valid options: 
    - `key`: `IO.device` providing the ssh key (required)
    - `known_hosts`: `IO.device` providing the known hosts list (required)
    - `accept_hosts`: `boolean` silently accept and add new hosts to the known hosts. By default only known hosts will be accepted. 
  """

  @behaviour :ssh_client_key_api

  @spec with_options(opts :: list) :: {atom, list}
  @doc """
    returns a tuple suitable for passing the `SSHKit.SSH.Connect` as the `key_cb` option.
#### Options
     - key_file - path to SSH key to use for authentication
     - known_hosts_file - path to file containing fingerprints of hosts to recognize
     - accept_hosts - whether or not to silently accept unknown host fingerprints
     
### Example

      `
      cb = SSHKit.SSH.ClientKeyApi.with_config(key_file: "path/to/keyfile", known_hosts_file: "path_to_known_hostsFile", accept_hosts: false)  
      SSHKit.SSH.connect("example.com", key_cb: cb)
      `

  """
  def with_options(opts) do
    opts = 
      opts
      |> Keyword.put(:key, File.open!(opts[:key_file]))
      |> Keyword.put(:known_hosts, File.open!(opts[:known_hosts_file]))   
    {__MODULE__, opts}
  end  

  def add_host_key(hostname, key, opts) do  
    case accept_hosts(opts) do
      true -> 
        opts
        |> known_hosts
        |> IO.read(:all)
        |> :public_key.ssh_decode(:known_hosts)
        |> (fn decoded -> decoded ++ [{key, [{:hostnames, [hostname]}]}] end).()
        |> :public_key.ssh_encode(:known_hosts)
        |> (fn encoded -> IO.write(known_hosts(opts), encoded) end).()
      _ -> 
        message = 
          """
          Error: unknown fingerprint found for #{inspect hostname} #{inspect key}.
          You either need to add a known good fingerprint to your known hosts file for this host,
          *or* pass the accept_hosts option to your client key callback
          """        
        {:error, message}
    end    
  end

  def is_host_key(key, hostname, _alg, opts) do
    opts
    |> known_hosts    
    |> IO.read(:all)
    |> :public_key.ssh_decode(:known_hosts)
    |> has_fingerprint(key, hostname)
  end

  def user_key(_alg, opts) do
    material =
      opts
      |> key
      |> IO.read(:all)
      |> :public_key.pem_decode
      |> List.first
      |> :public_key.pem_entry_decode
    {:ok, material}
  end

  defp key(opts) do
    cb_opts(opts)[:key]
  end

  defp accept_hosts(opts) do
    cb_opts(opts)[:accept_hosts]
  end

  defp known_hosts(opts) do
    cb_opts(opts)[:known_hosts]
  end

  defp cb_opts(opts) do
    opts[:key_cb_private]
  end

  defp has_fingerprint(fingerprints, key, hostname) do 
    Enum.any?(fingerprints, 
      fn {k, v} -> (k == key) && (Enum.member?(v[:hostnames], hostname)) end
      )
  end
end
