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
  @timing_stub 1.234

  # CLIENT

  @doc """
  Start the server.
  """
  @type statsd_port :: number
  @type host :: String.t
  @type sink :: String.t
  @type name :: String.t
  @type namespace :: String.t
  @type options :: [
    port: statsd_port,
    host: host,
    namespace: namespace,
    sink: sink,
    name: name
  ]
  @spec start_link(options) :: {:ok, pid}
  def start_link(options \\ []) do
    state = %{port:      Keyword.get(options, :port, default_config(:port, @default_port)),
              host:      Keyword.get(options, :host, default_config(:host, @default_host)) |> parse_host,
              namespace: Keyword.get(options, :namespace, default_config(:namespace, @default_namespace)),
              sink:      Keyword.get(options, :sink, default_config(:sink, @default_sink)),
              socket:    nil}
    GenServer.start_link(__MODULE__, state, Keyword.merge([name: __MODULE__], options))
  end

  @doc """
  Stop the server.
  """
  def stop(name \\ __MODULE__) do
    GenServer.stop(name)
  end

  @doc """
  Ensure the metrics are sent.
  """
  @spec flush :: :ok
  def flush(name \\__MODULE__) do
    GenServer.call(name, :flush)
  end

  @doc false
  defp parse_host(host) when is_binary(host) do
    case host |> to_char_list |> :inet.parse_address do
      {:error, _}    -> host |> String.to_atom
      {:ok, address} -> address
    end
  end

  # API

  @doc """
  Record a counter metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the amount given as its first argument, making it suitable
  for pipelining.
  """
  def counter(amount, metric, options \\ default_options()) do
    sampling options, fn(decision) ->
      case decision do
        {:sample, rate} ->
          {metric, amount, :c} |> transmit(options, rate)
          amount
        _ ->
          amount
      end
    end
  end

  @doc """
  Record the Enum.count/1 of an enumerable.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the collection given as its first argument, making it suitable for
  pipelining.
  """
  def count(collection, metric, options \\ default_options()) do
    value = collection |> Enum.count
    sampling options, fn(decision) ->
      case decision do
        {:sample, rate} ->
          {metric, value, :c} |> transmit(options, rate)
          collection
        _ ->
          collection
      end
    end
  end

  @doc """
  Record an increment to a counter metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  Returns `nil`.
  """
  def increment(metric, options \\ default_options()) do
    1 |> counter(metric, options)
    nil
  end

  @doc """
  Record a decrement to a counter metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  Returns `nil`.
  """
  def decrement(metric, options \\ default_options()) do
    -1 |> counter(metric, options)
    nil
  end

  @doc """
  Record a gauge entry.

  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the amount given as its first argument, making it suitable
  for pipelining.
  """
  def gauge(amount, metric, options \\ [tags: []]) do
    {metric, amount, :g} |> transmit(options)
    amount
  end

  @doc """
  Record a set metric.

  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the value given as its first argument, making it suitable
  for pipelining.
  """
  def set(member, metric, options \\ [tags: []]) do
    {metric, member, :s} |> transmit(options)
    member
  end

  @doc """
  Record a timer metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the value given as its first argument, making it suitable
  for pipelining.
  """
  def timer(amount, metric, options \\ default_options()) do
    sampling options, fn(decision) ->
      case decision do
        {:sample, rate} ->
          {metric, amount, :ms} |> transmit(options, rate)
          amount
        _ ->
          amount
      end
    end
  end

  @doc """
  Measure a function call.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the result of the function call, making it suitable
  for pipelining.
  """
  def timing(metric, fun, options \\ default_options()) do
    sampling options, fn(decision) ->
      case decision do
        {:sample, rate} ->
          {time, value} = :timer.tc(fun)
          amount = time / 1000.0
          # We should hard code the amount when we are in test mode.
          amount = if Application.get_env(:ex_statsd, :test_mode, false), do: @timing_stub, else: amount
          {metric, amount, :ms} |> transmit(options, rate)
          value
        _ ->
          fun.()
      end
    end
  end

  @doc """
  Record a histogram value (DogStatsD-only).

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the value given as the first argument, making it suitable for
  pipelining.
  """
  def histogram(amount, metric, options \\ default_options()) do
    sampling options, fn(decision) ->
      case decision do
        {:sample, rate} ->
          {metric, amount, :h} |> transmit(options, rate)
          amount
        _ ->
          amount
      end
    end
  end

  @doc """
  Time a function using a histogram metric (DogStatsD-only).

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)

  It returns the result of the function call, making it suitable
  for pipelining.
  """
  def histogram_timing(metric, fun, options \\ default_options()) do
    sampling options, fn(decision) ->
      case decision do
        {:sample, rate} ->
          {time, value} = :timer.tc(fun)
          amount = time / 1000.0
          # We should hard code the amount when we are in test mode.
          amount = if Application.get_env(:ex_statsd, :test_mode, false), do: @timing_stub, else: amount
          {metric, amount, :h} |> transmit(options, rate)
          value
        _ ->
          fun.()
      end
    end
  end

  defp default_config(key, fallback) do
    Application.get_env(:ex_statsd, key, fallback)
  end

  defp default_options, do: [sample_rate: 1, tags: [], name: __MODULE__]

  defp sampling(options, fun) when is_list(options) do
    case Keyword.get(options, :sample_rate, 1) do
      1 -> fun.({:sample, 1})
      sample_rate -> sample(sample_rate, fun)
    end
  end
  defp sample(sample_rate, fun) do
    case :random.uniform <= sample_rate do
      true -> fun.({:sample, sample_rate})
      _ -> fun.(:no_sample)
    end
  end

  defp transmit(message, options), do: transmit(message, options, 1)
  defp transmit(message, options, sample_rate) do
    name = Keyword.get(options, :name, __MODULE__)
    GenServer.cast(name, {:transmit, message, options, sample_rate})
  end

  defp packet({key, value, type}, namespace, tags, sample_rate) do
    [key |> stat_name(namespace),
     ":#{value}|#{type}",
     sample_rate |> sample_rate_suffix,
     tags |> tags_suffix
    ] |> IO.iodata_to_binary
  end

  defp sample_rate_suffix(1), do: ""
  defp sample_rate_suffix(sample_rate) do
    ["|@", :io_lib.format('~.2f', [sample_rate])]
  end

  defp tags_suffix([]), do: ""
  defp tags_suffix(tags) do
    ["|#", tags |> Enum.join(",")]
  end

  defp stat_name(key, nil), do: key
  defp stat_name(key, namespace), do: "#{namespace}.#{key}"

  # SERVER

  @doc false
  def handle_cast({:transmit, message, options, sample_rate}, %{sink: sink} = state) when is_list(sink) do
    tags = Keyword.get(options, :tags, [])
    pkt = message |> packet(state.namespace, tags, sample_rate)
    {:noreply, %{state | sink: [pkt | sink]}}
  end

  @doc false
  def handle_cast({:transmit, message, options, sample_rate}, state) do
    tags = Keyword.get(options, :tags, [])
    pkt = message |> packet(state.namespace, tags, sample_rate)
    {:ok, socket} = :gen_udp.open(0, [:binary])
    :gen_udp.send(socket, state.host, state.port, pkt)
    :gen_udp.close(socket)
    {:noreply, state}
  end

  @doc false
  def handle_call(:flush, _from, state) do
    {:reply, :ok, state}
  end
end
