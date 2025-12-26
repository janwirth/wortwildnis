defmodule Wortwildnis.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WortwildnisWeb.Telemetry,
      Wortwildnis.Repo,
      {DNSCluster, query: Application.get_env(:wortwildnis, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:wortwildnis, :ash_domains),
         Application.fetch_env!(:wortwildnis, Oban)
       )},
      {Phoenix.PubSub, name: Wortwildnis.PubSub},
      # Start a worker by calling: Wortwildnis.Worker.start_link(arg)
      # {Wortwildnis.Worker, arg},
      # Start to serve requests, typically the last entry
      WortwildnisWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :wortwildnis]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wortwildnis.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WortwildnisWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
