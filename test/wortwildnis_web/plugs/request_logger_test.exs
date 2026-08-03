defmodule WortwildnisWeb.Plugs.RequestLoggerTest do
  use WortwildnisWeb.ConnCase
  import ExUnit.CaptureLog

  alias WortwildnisWeb.Plugs.RequestLogger

  @moduletag :capture_log

  setup do
    # Temporarily set logger level to info for these tests
    original_level = Logger.level()
    Logger.configure(level: :info)

    on_exit(fn ->
      Logger.configure(level: original_level)
    end)

    :ok
  end

  test "logs request information with user agent", %{conn: conn} do
    conn =
      conn
      |> put_req_header("user-agent", "Mozilla/5.0 Test Browser")

    log =
      capture_log(fn ->
        RequestLogger.call(conn, [])
      end)

    assert log =~ "Request Info:"
    assert log =~ "Method: GET"
    assert log =~ "User-Agent: Mozilla/5.0 Test Browser"
    assert log =~ "IP Address:"
    assert log =~ "Request ID:"
  end

  test "handles missing user agent", %{conn: conn} do
    log =
      capture_log(fn ->
        RequestLogger.call(conn, [])
      end)

    assert log =~ "User-Agent: Unknown"
  end

  test "logs conn.remote_ip as resolved upstream by the RemoteIp plug", %{conn: conn} do
    # RemoteIp (wired in the endpoint ahead of this plug) is what's
    # responsible for trusting X-Forwarded-For; RequestLogger just logs
    # whatever conn.remote_ip already resolved to.
    conn = %{conn | remote_ip: {1, 2, 3, 4}}

    log =
      capture_log(fn ->
        RequestLogger.call(conn, [])
      end)

    assert log =~ "IP Address: 1.2.3.4"
  end

  test "does not itself trust a raw x-forwarded-for header", %{conn: conn} do
    # Without RemoteIp in front of it, RequestLogger must not fall back to
    # parsing the (client-spoofable) header itself.
    conn =
      conn
      |> put_req_header("x-forwarded-for", "9.9.9.9")
      |> Map.put(:remote_ip, {127, 0, 0, 1})

    log =
      capture_log(fn ->
        RequestLogger.call(conn, [])
      end)

    refute log =~ "9.9.9.9"
    assert log =~ "IP Address: 127.0.0.1"
  end

  test "redacts token query params", %{conn: conn} do
    conn = %{conn | query_string: "token=super-secret-value&q=hello"}

    log =
      capture_log(fn ->
        RequestLogger.call(conn, [])
      end)

    refute log =~ "super-secret-value"
    assert log =~ "token=[REDACTED]"
    assert log =~ "q=hello"
  end

  test "redacts token path segments for known auth routes", %{conn: conn} do
    conn = %{conn | request_path: "/password-reset/super-secret-token"}

    log =
      capture_log(fn ->
        RequestLogger.call(conn, [])
      end)

    refute log =~ "super-secret-token"
    assert log =~ "Path: /password-reset/[REDACTED]"
  end
end
