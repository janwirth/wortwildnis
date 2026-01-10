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

  test "handles x-forwarded-for header", %{conn: conn} do
    conn = put_req_header(conn, "x-forwarded-for", "1.2.3.4, 5.6.7.8")

    log =
      capture_log(fn ->
        RequestLogger.call(conn, [])
      end)

    assert log =~ "IP Address: 1.2.3.4"
  end
end
