defmodule WortwildnisWeb.Plugs.RequestLogger do
  @moduledoc """
  Plug to log request information including user agent, IP address, and other request metadata.
  """

  require Logger

  @behaviour Plug

  # Path prefixes whose next segment is a single-use auth token and must
  # never reach logs.
  @token_path_prefixes ["/password-reset/", "/confirm_new_user/", "/magic_link/"]

  # Query/body param keys that carry secrets.
  @sensitive_param_keys ~w(token password reset_token confirmation_token magic_link)

  def init(opts), do: opts

  def call(conn, _opts) do
    user_agent = get_user_agent(conn)
    ip_address = get_ip_address(conn)
    # Get request_id from assigns, which Plug.RequestId sets
    request_id = Map.get(conn.private, :plug_request_id, "N/A")

    Logger.info("""
    Request Info:
      Method: #{conn.method}
      Path: #{redact_path(conn.request_path)}
      User-Agent: #{user_agent}
      IP Address: #{ip_address}
      Request ID: #{request_id}
      Query String: #{redact_query_string(conn.query_string)}
    """)

    conn
  end

  defp redact_path(path) do
    if Enum.any?(@token_path_prefixes, &String.starts_with?(path, &1)) do
      prefix = Enum.find(@token_path_prefixes, &String.starts_with?(path, &1))
      prefix <> "[REDACTED]"
    else
      path
    end
  end

  defp redact_query_string(""), do: ""

  defp redact_query_string(query_string) do
    query_string
    |> String.split("&")
    |> Enum.map(fn pair ->
      case String.split(pair, "=", parts: 2) do
        [key, _value] ->
          if String.downcase(key) in @sensitive_param_keys do
            key <> "=[REDACTED]"
          else
            pair
          end

        _ ->
          pair
      end
    end)
    |> Enum.join("&")
  end

  defp get_user_agent(conn) do
    case Plug.Conn.get_req_header(conn, "user-agent") do
      [user_agent | _] -> user_agent
      [] -> "Unknown"
    end
  end

  defp get_ip_address(conn) do
    # RemoteIp plug (wired in the endpoint, ahead of this plug) resolves
    # conn.remote_ip from X-Forwarded-For only when the immediate peer is a
    # trusted proxy, so this is no longer spoofable by the client.
    case conn.remote_ip do
      {a, b, c, d} -> "#{a}.#{b}.#{c}.#{d}"
      {a, b, c, d, e, f, g, h} -> "#{a}:#{b}:#{c}:#{d}:#{e}:#{f}:#{g}:#{h}"
      _ -> "Unknown"
    end
  end
end
