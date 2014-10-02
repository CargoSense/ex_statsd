defmodule ExStatsD do
  @moduledoc """
  Settings are taken from the `ex_statsd` application configuration.

  The following are used to connect to your statsd server:

   * `host`: The hostname or IP address (default: 127.0.0.1)
   * `port`: The port number (default: 8125)

  You can also provide an optional `namespace` to automatically nest all
  stats.
  """

  use GenServer

  @default_port 8125
  @default_host "127.0.0.1"
  @default_namespace nil
  @default_sink nil

  # CLIENT

  @doc """
  Start the server.
  """
  def start_link do
    state = %{port:      Application.get_env(:ex_statsd, :port, @default_port),
              host:      Application.get_env(:ex_statsd, :host, @default_host) |> parse_host,
              namespace: Application.get_env(:ex_statsd, :namespace, @default_namespace),
              sink:      Application.get_env(:ex_statsd, :sink, @default_sink),
              socket:    nil}
    if state.sink do
      GenServer.start_link(__MODULE__, state, [name: __MODULE__])
    else
      {:ok, socket} = :gen_udp.open(0)
      GenServer.start_link(__MODULE__, %{state | socket: socket}, [name: __MODULE__])
    end
  end

  @doc """
  Stop the server.
  """
  def stop do
    GenServer.call(__MODULE__, :stop)
  end

  @doc false
  defp parse_host(host) when is_binary(host) do
    case host |> to_char_list |> :inet.parse_address do
      {:error, _}    -> host |> String.to_atom
      {:ok, address} -> address
    end
  end

  # API

  def counter(amount, metric, options \\ [sample_rate: 1]) do
    sampling options, fn(rate) ->
      {metric, amount, :c} |> transmit(rate)
    end
  end

  def increment(metric, options \\ [sample_rate: 1]) do
    1 |> counter(metric, options)
  end

  def decrement(metric, options \\ [sample_rate: 1]) do
    -1 |> counter(metric, options)
  end

  def gauge(amount, metric), do: {metric, amount, :g} |> transmit

  def set(member, metric), do: {metric, member, :s} |> transmit

  def timer(amount, metric, options \\ [sample_rate: 1]) do
    sampling options, fn(rate) ->
      {metric, amount, :ms} |> transmit(rate)
    end
  end

  @doc """
  Time a function at an optional sample rate.


  """
  def timing(metric, fun, options \\ [sample_rate: 1]) do
    sampling options, fn(rate) ->
      {time, _} = :timer.tc(fun)
      amount = time / 1000.0
      {metric, amount, :ms} |> transmit(rate)
    end
  end

  defp sampling(options, fun) when is_list(options) do
    case Keyword.fetch!(options, :sample_rate) do
      1 -> fun.(1)
      sample_rate -> sample(sample_rate, fun)
    end
  end
  defp sample(sample_rate, fun) do
    case :random.uniform <= sample_rate do
      true -> fun.(sample_rate)
      _ -> :not_sampled
    end
  end

  @doc false
  defp transmit(message), do: transmit(message, 1)
  defp transmit(message, sample_rate) do
    GenServer.cast(__MODULE__, {:transmit, message, sample_rate})
  end

  @doc """
  Generate the StatsD packet representation.

  It expects a `message` with the key, value, and type sigil, a `namespace`
  (that may be `nil`), and a `sample_rate` (that may be `1`).
  """
  defp packet(message, namespace), do: packet(message, namespace, 1)
  defp packet({key, value, type}, namespace, sample_rate) do
    [key |> stat_name(namespace),
     ":#{value}|#{type}",
     sample_rate |> sample_rate_suffix
    ] |> IO.iodata_to_binary
  end

  @doc """
  Generate the packet suffix for a sample rate.

  The suffix is empty if the sample rate is `1`.
  """
  defp sample_rate_suffix(1), do: ""
  defp sample_rate_suffix(sample_rate) do
    ["|@", :io_lib.format('~.2f', [1.0 / sample_rate])]
  end

  @doc """
  Generate the dotted stat name for a `key` in `namespace`.
  """
  defp stat_name(key, nil), do: key
  defp stat_name(key, namespace), do: "#{namespace}.#{key}"

  # SERVER

  @doc false
  def handle_cast({:transmit, message, sample_rate}, %{sink: sink} = state) when is_list(sink) do
    pkt = message |> packet(state.namespace, sample_rate)
    {:noreply, %{state | sink: [pkt | sink]}}
  end

  @doc false
  def handle_cast({:transmit, message, sample_rate}, state) do
    pkt = message |> packet(state.namespace, sample_rate)
    :gen_udp.send(state.socket, state.host, state.port, pkt)
    {:noreply, state}
  end

  @doc false
  def handle_call(:stop, state) do
    if state.socket, do: :gen_udp.close(state.socket)
    {:reply, state}
  end

end
