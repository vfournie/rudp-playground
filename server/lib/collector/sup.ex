defmodule RudpServer.Collector.Supervisor do
    use Supervisor

    def start_link() do
        Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
    end

    def init(:ok) do
        # Initialize the :ets table that will contain the stats
        :ets.new(:rudp_stats, [:set, :public, :named_table, {:read_concurrency, true}, {:write_concurrency, true}])

        children = [
            worker(RudpServer.Collector, [])
        ]

        supervise(children, strategy: :one_for_one)
    end

end
