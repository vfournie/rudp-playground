defmodule RudpServer do
    use Application
    require Logger

    @so_sndbuf_size 2097152 # 2 MB
    @so_rcvbuf_size 2097152 # 2 MB

    def start(_type, _args) do
        import Supervisor.Spec, warn: false

        # Initialize the RUDP listener
        port = Application.get_env(:rudp_server, :udp_port)
        acceptors_count = Application.get_env(:rudp_server, :acceptors_count, 10)
		opts = [reuseaddr: true, recbuf: @so_rcvbuf_size, sndbuf: @so_sndbuf_size]
        {:ok, listener} = :gen_rudp.start_listener(port, opts)
        Logger.info("RUDP server listening on UDP port #{port}")

        children = [
            supervisor(RudpServer.Collector.Supervisor, []),
            supervisor(RudpServer.Worker.Supervisor, [[acceptors_count, listener]]),
        ]

        opts = [strategy: :one_for_one, name: RudpServer.Supervisor]
        Supervisor.start_link(children, opts)
    end

end
