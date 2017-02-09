defmodule RudpServer.Worker do
    use GenServer
    require Logger

    defmodule State do
        defstruct [
            listener: nil,
            socket: nil,
            acceptor_id: nil,
        ]
    end

    ## Client API

	def start_link([_listener, _acceptor_id] = args) do
        :proc_lib.start_link(__MODULE__, :init, [args])
	end

    ## Server Callbacks

	def init([listener, acceptor_id]) do
        :ok = :proc_lib.init_ack({:ok, self()})

        state =
            with {:ok, socket} <- :gen_rudp.accept(listener)
            do
                Logger.info("RUDP server accepting connections on #{inspect socket}")
                %State{
                    listener: listener,
                    socket: socket,
                    acceptor_id: acceptor_id,
                }
            else error ->
                Logger.info("RUDP server failed to accept connections (#{inspect error})")
                %State{
                    listener: listener,
                    acceptor_id: acceptor_id,
                }
            end

        :gen_server.enter_loop(__MODULE__, [], state)
	end

    def handle_info({:rudp_connected, _socket, address, port}, state) do
        Logger.info("RUDP server connected to #{inspect address}:#{inspect port}")

        {:noreply, state}
    end

    def handle_info({:rudp_received, socket, data}, state) do
        process_packet(socket, data, state)

		{:noreply, state}
    end

    def handle_info({:rudp_closed, socket, _reason}, state) do
        :gen_rudp.close(socket)

        {:noreply, state}
    end

    def handle_info(_any, state) do
        {:noreply, state}
    end

    def terminate(_reason, %State{socket: socket} = _state) do
        :gen_rudp.close(socket)
    end

    ## Private

    defp process_packet(socket, data, %State{acceptor_id: acceptor_id} = _state) do
        # Update recv counter
        recv_counter = {:recv, acceptor_id}
        RudpServer.Collector.inc_counter(recv_counter)

        # Send back the packet
        :gen_rudp.async_send_binary(socket, data)

        # Update send counter
        send_counter = {:send, acceptor_id}
        RudpServer.Collector.inc_counter(send_counter)
    end

end
