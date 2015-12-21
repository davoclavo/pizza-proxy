defmodule Pizza.Server do
  use Application

  def start(_type, _args) do
    port = Application.get_env(:pizza, :server)[:http][:port]
    IO.puts "Running on http://localhost:#{port}"
    # Plug.Adapters.Cowboy.http Pizza.Plug, [port: port]
    Plug.Adapters.Cowboy.http Pizza.Proxy, [port: port]
  end
end
