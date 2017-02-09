# RUDP Client

RUDP client OTP app.  
The app allows to spawn a specified number of clients that will send a ping packet to a server every 200 ms.

## Running

Prerequesites:
- Elixir 1.3.X
- Erlang 1.9.X

### Dependencies

If it's a fresh clone or updated branch, do:
```
> mix deps.get
```

### Run

To run the client:
```
> iex -S mix
```

To start N clients (connecting to localhost:4055), issue the following in the iex shell:
```
iex(1)> RudpClient.start_clients(100)
```

To start N clients connecting to a specific IP address / port, issue the following in the iex shell:
```
iex(1)> RudpClient.start_clients(100, "127.0.0.1", 4055)
```

To see the statistics, issue the following in the iex shell:
```
iex(2)> RudpClient.Collector.display_stats
```
