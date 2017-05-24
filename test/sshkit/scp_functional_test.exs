defmodule SSHKit.SCPFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SCP
  alias SSHKit.SSH

  @defaults [silently_accept_hosts: true]
  @local_workspace "test/fixtures/local_workspace"
  @remote_workspace "/workspace"
  @local_remote_workspace "test/fixtures/docker_workspace"

  describe "upload" do

    @tag boot: 1
    test "to host directly", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      local = "#{@local_workspace}/local_file.txt"
      remote = "#{@remote_workspace}/#{host.id}.file"
      shared = "#{@local_remote_workspace}/#{host.id}.file"

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))
      assert :ok = SCP.upload(conn, local, remote)
      assert File.read(local) == File.read(shared)
      File.rm!(shared)
    end

    @tag boot: 2
    test "using a context", %{hosts: hosts} do
      local = "#{@local_workspace}/local_file.txt"
      remote = "#{@remote_workspace}/destination.file"
      shared = "#{@local_remote_workspace}/destination.file"

      hosts = Enum.map(hosts,
        fn(h) ->
          SSHKit.host(h.ip, Keyword.merge(@defaults, [port: h.port, user: h.user, password: h.password]))
        end)
      context = SSHKit.context(hosts)

      assert [:ok, :ok] = SSHKit.upload(context, local, as: remote)
      assert File.read(local) == File.read(shared)
      File.rm!(shared)
    end

    @tag boot: 1
    test "using a context with a path", %{hosts: hosts} do
      local = "local_file.txt"
      shared = "#{@local_remote_workspace}/local_file.txt"
      hosts = Enum.map(hosts,
        fn(h) ->
          SSHKit.host(h.ip, Keyword.merge(@defaults, [port: h.port, user: h.user, password: h.password]))
        end)
      context = hosts |> SSHKit.context |> SSHKit.path(@remote_workspace)

      project_dir = File.cwd!
      File.cd(@local_workspace)
      assert [:ok] = SSHKit.upload(context, local)
      File.cd(project_dir)

      assert File.read("#{@local_workspace}/#{local}") == File.read(shared)
      File.rm!(shared)
    end

    @tag boot: 1
    test "using a context with a destination override", %{hosts: hosts} do
      local = "#{@local_workspace}/local_file.txt"
      remote = "#{@remote_workspace}/destination.file"
      shared = "#{@local_remote_workspace}/destination.file"

      hosts = Enum.map(hosts,
        fn(h) ->
          SSHKit.host(h.ip, Keyword.merge(@defaults, [port: h.port, user: h.user, password: h.password]))
        end)
      context = hosts |> SSHKit.context |> SSHKit.path("~/")

      assert [:ok] = SSHKit.upload(context, local, as: remote)
      assert File.read(local) == File.read(shared)
      File.rm!(shared)
    end
  end

  describe "download" do
    @tag boot: 1
    test "from host directly", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      remote = "#{@remote_workspace}/remote_file.txt"
      local = "#{@local_workspace}/#{host.id}.file"
      shared = "#{@local_remote_workspace}/remote_file.txt"

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))
      assert :ok = SCP.download(conn, remote, local)
      assert File.read(shared) == File.read(local)
      File.rm!(local)
    end

    @tag boot: 2
    test "using a context", %{hosts: hosts} do
      remote = "#{@remote_workspace}/remote_file.txt"
      local = "#{@local_workspace}/destination.file"
      shared = "#{@local_remote_workspace}/remote_file.txt"

      hosts = Enum.map(hosts,
        fn(h) ->
          SSHKit.host(h.ip, Keyword.merge(@defaults, [port: h.port, user: h.user, password: h.password]))
        end)
      context = SSHKit.context(hosts)

      assert [:ok, :ok] = SSHKit.download(context, remote, as: local)
      assert File.read(shared) == File.read(local)
      File.rm!(local)
    end

    @tag boot: 1
    test "using a context with a path", %{hosts: hosts} do
      path = "remote_file.txt"
      shared = "#{@local_remote_workspace}/remote_file.txt"

      hosts = Enum.map(hosts,
        fn(h) ->
          SSHKit.host(h.ip, Keyword.merge(@defaults, [port: h.port, user: h.user, password: h.password]))
        end)
      context = hosts |> SSHKit.context |> SSHKit.path(@remote_workspace)

      project_dir = File.cwd!
      File.cd(@local_workspace)
      assert [:ok] = SSHKit.download(context, path)
      File.cd(project_dir)

      assert File.read(shared) == File.read("#{@local_workspace}/#{path}")
      File.rm!("#{@local_workspace}/#{path}")
    end

    @tag boot: 1
    test "using a context with a destination override", %{hosts: hosts} do
      remote = "remote_file.txt"
      local = "#{@local_workspace}/destination.file"
      shared = "#{@local_remote_workspace}/remote_file.txt"

      hosts = Enum.map(hosts,
        fn(h) ->
          SSHKit.host(h.ip, Keyword.merge(@defaults, [port: h.port, user: h.user, password: h.password]))
        end)
      context = hosts |> SSHKit.context |> SSHKit.path(@remote_workspace)

      assert [:ok] = SSHKit.download(context, remote, as: local)
      assert File.read(shared) == File.read(local)
      File.rm!(local)
    end
  end
end
