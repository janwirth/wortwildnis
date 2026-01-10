defmodule WortwildnisWeb.Plugs.RequestLogger do
  @moduledoc """
  Plug to log request information including user agent, IP address, and other request metadata.
  """

  require Logger

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    user_agent = get_user_agent(conn)
    ip_address = get_ip_address(conn)
    # Get request_id from assigns, which Plug.RequestId sets
    request_id = Map.get(conn.private, :plug_request_id, "N/A")

    Logger.info("""
    Request Info:
      Method: #{conn.method}
      Path: #{conn.request_path}
      User-Agent: #{user_agent}
      IP Address: #{ip_address}
      Request ID: #{request_id}
      Query String: #{conn.query_string}
    """)

    conn
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "Unknown"
    end
  end

  defp get_ip_address(conn) do
    # Check for forwarded IP first (for when behind a proxy/load balancer)
    forwarded_for = Plug.Conn.get_req_header(conn, "x-forwarded-for")

    case forwarded_for do
      [ip | _] ->
        # x-forwarded-for can contain multiple IPs, take the first one
        ip |> String.split(",") |> List.first() |> String.trim()

      [] ->
        # Fall back to remote_ip from the connection
        case conn.remote_ip do
          {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
          {a, b, c, d, e, f, g, h} -> "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
          _ -> "Unknown"
        end
    end
  end
end
