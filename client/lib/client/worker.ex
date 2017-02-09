defmodule RudpClient.Worker do
    use GenServer
    require Logger

    @so_sndbuf_size 2097152 # 2 MB
    @so_rcvbuf_size 2097152 # 2 MB

    defmodule State do
        defstruct [
            listener: nil,
            socket: nil,
            client_id: nil,
            timer_pid: nil,
        ]
    end

    ## Client API

    def start_link([_address, _port, _client_id] = args) do
        :proc_lib.start_link(__MODULE__, :init, [args])
	end

    def start_ping(pid, initial_delay \\ 0) do
        GenServer.call(pid, {:start_ping, initial_delay})
    end

    def stop_ping(pid) do
        GenServer.call(pid, :stop_ping)
    end

    def stop(pid) do
        GenServer.stop(pid)
    end

    ## Server Callbacks

	def init([address, port, client_id]) do
        :ok = :proc_lib.init_ack({:ok, self()})

		opts = [reuseaddr: true, recbuf: @so_rcvbuf_size, sndbuf: @so_sndbuf_size]

        state =
            with {:ok, listener} <- :gen_rudp.start_listener(0, opts),
                 {:ok, socket} <- :gen_rudp.connect(listener, String.to_charlist(address), port, []),
                 {:ok, timer_pid} <- RudpClient.Worker.SendTimer.start_link([socket, client_id])
            do
                Logger.info("RUDP client connect on #{inspect socket}")
                %State{
                    listener: listener,
                    socket: socket,
                    timer_pid: timer_pid,
                    client_id: client_id,
                }
            else error ->
                Logger.info("RUDP client failed to connect (#{inspect error})")
                %State{
                    client_id: client_id,
                }
            end

        :gen_server.enter_loop(__MODULE__, [], state)
	end

    def handle_call({:start_ping, initial_delay}, _from, %State{timer_pid: timer_pid} = state) do
        RudpClient.Worker.SendTimer.start_timer(timer_pid, initial_delay)

        {:reply, :ok, state}
    end

    def handle_call(:stop_ping, _from, %State{timer_pid: timer_pid} = state) do
        RudpClient.Worker.SendTimer.stop_timer(timer_pid)

        {:reply, :ok, state}
    end

    def handle_info({:rudp_connected, _socket, address, port}, state) do
        Logger.info("RUDP client connected to #{inspect address}:#{inspect port}")
        {:noreply, state}
    end

    def handle_info({:rudp_received, _socket, binary}, %State{client_id: client_id} = state) do
        # Update recv counter
        recv_counter = {:recv, client_id}
        RudpClient.Collector.inc_counter(recv_counter)

        process_packet(binary, client_id)

        {:noreply, state}
    end

    def handle_info({:rudp_closed, _socket, reason }, state) do
        Logger.info("RUDP client closed #{inspect reason}")
        {:noreply, state}
    end

    def handle_info(_any, state) do
        {:noreply, state}
    end

    def terminate(_reason, %State{socket: socket} = _state) do
        :gen_rudp.close(socket)
    end

    # Private

    def process_packet(binary, client_id)

    def process_packet(<<
                        10 :: size(16),
                        time :: signed-integer-size(64),
                       >>,
                       client_id) do
        curr_time = System.monotonic_time(:milliseconds)
        delta = curr_time - time

        :ets.insert_new(:rudp_stats, {{:pong, client_id, time}, delta})
    end

    def process_packet(_, _client_id) do
        :ok
    end

end

defmodule RudpClient.Worker.SendTimer do
    use GenServer
    require Logger

    @period         200   # Period between executions (in ms)

    defmodule State do
        defstruct [
            socket: nil,
            timer: nil,
            client_id: nil,
        ]
    end

    ## Client API

    def start_link([_socket, _client_id] = args) do
        GenServer.start_link(__MODULE__, args)
	end

    def start_timer(pid, initial_delay) do
        GenServer.call(pid, {:start_timer, initial_delay})
    end

    def stop_timer(pid) do
        GenServer.call(pid, :stop_timer)
    end

    ## Server Callbacks

	def init([socket, client_id]) do
        {:ok,  %State{socket: socket, client_id: client_id}}
    end

    def handle_call({:start_timer, initial_delay}, _from, state) do
        timer = Process.send_after(self(), :ping, initial_delay)

        {:reply, :ok, %State{state | timer: timer}}
    end

    def handle_call(:stop_timer, _from, %State{timer: timer} = state) do
        cancel_timer(timer)

        {:reply, :ok, %State{state | timer: nil}}
    end

    def handle_info(:ping, %State{socket: socket, client_id: client_id} = state) do
        # Send ping
        monotonic_time = System.monotonic_time(:milliseconds)
        packet = <<
            10 :: size(16),
            monotonic_time :: signed-integer-size(64),
        >>
        :gen_rudp.async_send_binary(socket, packet)

        # Update send counter
        send_counter = {:send, client_id}
        RudpClient.Collector.inc_counter(send_counter)

        # Start the timer again
        timer = Process.send_after(self(), :ping, @period)

        {:noreply, %State{state | timer: timer}}
    end

    def handle_info(_any, state) do
        {:noreply, state}        
    end

    ## Pivate

    defp cancel_timer(timer)
    defp cancel_timer(nil),     do: :ok
    defp cancel_timer(timer),   do: Process.cancel_timer(timer)

end
