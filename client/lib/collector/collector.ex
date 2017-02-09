defmodule RudpClient.Collector do
    use GenServer
    require Logger

    ## Client API

	def start_link() do
		GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
	end

    def inc_counter(counter)  do
        GenServer.call(__MODULE__, {:inc_counter, counter})
    end

    def get_raw_stats() do
        GenServer.call(__MODULE__, :get_raw_stats)
    end

    def display_stats() do
        GenServer.call(__MODULE__, :display_stats)
    end

    ## Server Callbacks

	def init(:ok) do
        {:ok, %{}}
    end

    def handle_call({:inc_counter, counter}, _from, state) do
        :ets.update_counter(:rudp_stats, counter, 1, {1, 0})

        {:reply, :ok, state}
    end

    def handle_call(:get_raw_stats, _from, state) do
        stats = :ets.match(:rudp_stats, :"$1")

        {:reply, stats, state}
    end

    def handle_call(:display_stats, _from, state) do
        dump_stats()

        {:reply, :ok, state}
    end

    # Private

    defp dump_stats() do
        pong_values = :ets.match(:rudp_stats, {{:pong, :"_", :"_"}, :"$1"}) |> Enum.flat_map(&(&1))

        pong_count = Enum.count(pong_values)
        {pong_min, pong_max, pong_mean} = case pong_count > 0 do
            true ->            
                pong_min = Enum.min(pong_values)
                pong_max = Enum.max(pong_values)
                pong_mean = (Enum.sum(pong_values) / pong_count) |> trunc
                {pong_min, pong_max, pong_mean}
            _ ->
                {0, 0, 0}
        end
        IO.puts(
        """
        Stats:
            #{inspect pong_count}\t\tUDP Pong packets received:
                                Min  round trip duration (in ms):\t#{inspect pong_min} ms
                                Mean round trip duration (in ms):\t#{inspect pong_mean} ms
                                Max  round trip duration (in ms):\t#{inspect pong_max} ms
        """
        )
    end

end
