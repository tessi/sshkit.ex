defmodule SSHKit do
  @moduledoc """
  A toolkit for performing tasks on one or more servers.

  ```
  hosts = ["1.eg.io", {"2.eg.io", port: 2222}]
  hosts = [%SSHKit.Host{name: "3.eg.io", options: [port: 2223]} | hosts]

  context =
    SSHKit.context(hosts)
    |> SSHKit.path("/var/www/phx")
    |> SSHKit.user("deploy")
    |> SSHKit.group("deploy")
    |> SSHKit.umask("022")
    |> SSHKit.env(%{"NODE_ENV" => "production"})

  :ok = SSHKit.upload(context, ".", recursive: true)
  :ok = SSHKit.run(context, "yarn install", mode: :parallel)
  ```
  """

  alias SSHKit.SCP
  alias SSHKit.SSH

  alias SSHKit.Context
  alias SSHKit.Host

  @doc """
  Produces a `SSHKit.Host` struct holding the information
  needed to connect to a (remote) host.

  ## Examples

  In its most basic version, you just pass a hostname and all other options will use the defaults:

  ```
  host = SSHKit.host("name.io")
  ```

  If you wish to provide additional host options, e.g. a non-standard port, you can pass a second argument:

  ```
  host = SSHKit.host(name: "name.io", port: 2222)
  ```

  … or, alternatively, a tuple with hostname and options:

  ```
  host = SSHKit.host({"name.io", port: 2222})
  ```

  One or many of these hosts can then be used
  to create an execution context in which commands
  can be executed.

  ```
  host
  |> SSHKit.context
  |> SSHKit.run("echo \"That was fun\"")
  ```
  """
  def host(%{name: name, options: options}) do
    %Host{name: name, options: options}
  end

  def host({name, options}) do
    %Host{name: name, options: options}
  end

  @doc """
  See `host/1` for details and examples.
  """
  def host(name, options \\ []) do
    %Host{name: name, options: options}
  end

  @doc """
  Takes one or more (remote) hosts and creates
  an execution context in which remote commands can be run.

  See `path/2`, `umask/2`, `user/2`, `group/2`, or `env/2`
  for details on how to modify a context.

  ## Example

  Create an execution context for two hosts.
  Commands issued on that context will be executed
  on both hosts.

  ```
  hosts = ["10.0.0.1", "10.0.0.2"]
  context = SSHKit.context(hosts)
  ```
  """
  def context(hosts) do
    hosts =
      hosts
      |> List.wrap
      |> Enum.map(&host/1)
    %Context{hosts: hosts}
  end

  @doc """
  Changes the working directory commands are executed in
  for the given context.
  It returns the modified context for easy chaining.

  ## Example

  ```
  # creates /var/www/my_app/my_file

  "10.0.0.1"
  |> SSHKit.context
  |> SSHKit.path("/var/www/my_app")
  |> SSHKit.run("touch my_file")
  ```
  """
  def path(context, path) do
    %Context{context | path: path}
  end

  @doc """
  Changes the umask affecting default file/directory
  permissions.
  It returns the modified context for easy chaining.

  ## Example

  ```
  # creates my_file, readable and writable only for the logged in user

  "10.0.0.1"
  |> SSHKit.context
  |> SSHKit.umask("077")
  |> SSHKit.run("touch my_file")
  ```
  """
  def umask(context, mask) do
    %Context{context | umask: mask}
  end

  @doc """
  Specifies the user under whose name commands are executed.
  That user might be different than the user with which
  ssh connects to the remote host.
  It returns the modified context for easy chaining.

  ## Example

  ```
  context =
    {"10.0.0.1", [port: 3000, user: "login_user", password: "secret"]}
    |> SSHKit.context
    |> SSHKit.user("deploy_user")
  ```

  All commands executed in the created `context` are
  run under the user `deploy_user`, although we used
  the `login_user` to log in to the remote host.
  """
  def user(context, name) do
    %Context{context | user: name}
  end

  @doc """
  Specifies the unix group commands are executed with.
  It returns the modified context for easy chaining.

  ## Example

  ```
  context =
    "10.0.0.1"
    |> SSHKit.context
    |> SSHKit.group("www")
  ```
  """
  def group(context, name) do
    %Context{context | group: name}
  end

  @doc """
  Defines new environment variables or overrides existing ones
  for a given context.
  It returns the modified context for easy chaining.

  ## Examples

  Setting `NODE_ENV=production`:
  ```
  context =
    "10.0.0.1"
    |> SSHKit.context
    |> SSHKit.env(%{"NODE_ENV" => "production"})

  # runs with NODE_ENV=production
  SSHKit.run(context, "npm start")
  ```

  Modifying the `PATH`:
  ```
  context =
    "10.0.0.1"
    |> SSHKit.context
    |> SSHKit.env(%{"PATH" => "$HOME/.rbenv/shims:$PATH"})

  # Executes the rbenv-installed ruby to output "hello world"
  SSHKit.run(context, "ruby -e \"puts 'hello world'\"")
  ```
  """
  def env(context, map) do
    %Context{context | env: map}
  end

  @doc ~S"""
  Executes a command within the given context.
  Returns a list of tuples of the form `{:ok, output, exit_code}`.
  There is one tuple per connected host a command was executed at.

  * `exit_code` is the number with which the executed command returns.
    If things went well, that usually is `0`.

  * `output` is a keyword list of the commands collected output.
    It has the form:
    ```
    [
      stdout: "output on standard out",
      stderr: "output on standard error",
      stdout: "some more normal output",
    ]
    ```

  ## Example

  Run a command and verify its output.

  ```
  {:ok, output, 0} =
    "my.remote-host.tld"
    |> SSHKit.context
    |> SSHKit.run("echo \"Hello World!\"")

  # join captured output fragments from stdout
  stdout =
    output
    |> Keyword.get_values(:stdout)
    |> Enum.join()

  assert "Hello World!\n" == stdout
  ```
  """
  def run(context, command) do
    cmd = Context.build(context, command)

    run = fn host ->
      {:ok, conn} = SSH.connect(host.name, host.options)
      res = SSH.run(conn, cmd)
      :ok = SSH.close(conn)
      res
    end

    Enum.map(context.hosts, run)
  end

  @doc ~S"""
  Upload a file or files to the given context.
  Returns a list of `:ok`.
  There is one `:ok` per connected host where file upload was successful.

  ## Examples

  Upload all files and folders in current directory to "/workspace".

  ```
  [:ok] =
    "my.remote-host.tld"
    |> SSHKit.context
    |> SSHKit.path("/workspace")
    |> SSHKit.upload(".", recursive: true)

  ```

  Upload file to different name on host

  ```
  [:ok] =
    "my.remote-host.tld"
    |> SSHKit.context
    |> SSHKit.upload("some_file.txt", as: "other_file.txt" )

  ```

  """
  def upload(context, path, options \\ []) do
    # resolve remote relative to context path
    # override with :as option if present
    destination_path = if (context.path), do: context.path, else: ""
    destination = case Keyword.get(options, :as, false) do
      false -> path
      override -> override
    end
    remote = if (Path.type(destination) == :absolute), do: destination, else: Path.join(destination_path, destination)

    run = fn host ->
      {:ok, conn} = SSH.connect(host.name, host.options)
      SCP.upload(conn, path, remote, options)
    end

    Enum.map(context.hosts, run)
  end

  @doc ~S"""
  Download a file or files from the given context.
  Returns a list of `:ok`.
  There is one `:ok` per connected host where file download was successful.

  ## Examples

  Download all files and folders in context directory to current working directory.

  ```
  [:ok] =
    "my.remote-host.tld"
    |> SSHKit.context
    |> SSHKit.path("/workspace")
    |> SSHKit.upload(".", recursive: true)

  ```

  Download file to different local name.

  ```
  [:ok] =
    "my.remote-host.tld"
    |> SSHKit.context
    |> SSHKit.download("some_file.txt", as: "other_file.txt" )

  ```

  """
  def download(context, path, options \\ []) do

    # resolve remote relative to context path
    remote = case context.path do
      nil -> path
      _ -> Path.join(context.path, path)
    end
    local = Keyword.get(options, :as, Path.basename(path))

    run = fn host ->
      {:ok, conn} = SSH.connect(host.name, host.options)
      SCP.download(conn, remote, local, options)
    end

    Enum.map(context.hosts, run)
  end
end
