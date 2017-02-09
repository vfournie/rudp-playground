defmodule RudpServer.Worker.Supervisor do
    use Supervisor

    def start_link(args) do
        Supervisor.start_link(__MODULE__, args, name: __MODULE__)
    end

    def init([acceptors_count, listener]) do
        children = Enum.map(1..acceptors_count, fn(n) ->
            worker(RudpServer.Worker, [[listener, n]], id: "rudp_worker_#{n}")
        end)

        supervise(children, strategy: :one_for_one)
    end

end
