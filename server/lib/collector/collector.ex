defmodule RudpServer.Collector do
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
        counters = :ets.match(:rudp_stats, :"$1")

        {:reply, counters, state}
    end

    def handle_call(:display_stats, _from, state) do
        dump_stats()

        {:reply, :ok, state}
    end

    # Private

    defp dump_stats() do
        nb_send = :ets.match(:rudp_stats, {{:recv, :"_"}, :"$1"}) |> Enum.flat_map(&(&1)) |> Enum.sum
        nb_recv = :ets.match(:rudp_stats, {{:recv, :"_"}, :"$1"}) |> Enum.flat_map(&(&1)) |> Enum.sum

        IO.puts(
        """
        Stats:
            #{inspect nb_recv}\t\tUDP packets received
            #{inspect nb_send}\t\tUDP packets sent
        """
        )
    end

end
