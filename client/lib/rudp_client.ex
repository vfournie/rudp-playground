defmodule RudpClient do
    use Application
    require Logger

    def start(_type, _args) do
        import Supervisor.Spec, warn: false

        children = [
            supervisor(RudpClient.Collector.Supervisor, []),
            supervisor(RudpClient.Worker.Supervisor, []),
        ]

        opts = [strategy: :one_for_one, name: RudpClient.Supervisor]
        Supervisor.start_link(children, opts)
    end

    def start_client(address, port, client_id) do
        RudpClient.Worker.Supervisor.start_child(address, port, client_id)
    end

    def start_client(client_id) do
        address = "127.0.0.1"
        port = Application.get_env(:rudp_client, :udp_port)
        start_client(address, port, client_id)
    end

    def start_clients(nb_clients) do
        Enum.each(1..nb_clients, fn(client_id) ->
            {:ok, client} = start_client(client_id)
            initial_delay = Enum.random(50..300)
            RudpClient.Worker.start_ping(client, initial_delay)
        end)
    end

end
