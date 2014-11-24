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
  def start_link(options \\ []) do
    state = %{port:      Application.get_env(:ex_statsd, :port, @default_port),
              host:      Application.get_env(:ex_statsd, :host, @default_host) |> parse_host,
              namespace: Application.get_env(:ex_statsd, :namespace, @default_namespace),
              sink:      Application.get_env(:ex_statsd, :sink, @default_sink),
              socket:    nil}
    GenServer.start_link(__MODULE__, state, [name: __MODULE__] ++ options)
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

  @doc """
  Record a counter metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)
  """
  def counter(amount, metric, options \\ [sample_rate: 1, tags: []]) do
    sampling options, fn(rate) ->
      {metric, amount, :c} |> transmit(options, rate)
    end
  end

  @doc """
  Record an increment to a counter metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)
  """
  def increment(metric, options \\ [sample_rate: 1, tags: []]) do
    1 |> counter(metric, options)
  end

  @doc """
  Record a decrement to a counter metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)
  """
  def decrement(metric, options \\ [sample_rate: 1, tags: []]) do
    -1 |> counter(metric, options)
  end

  @doc """
  Record a gauge entry.

  * `tags`: Add tags to entry (DogStatsD-only)
  """
  def gauge(amount, metric, options \\ [tags: []]) do
    {metric, amount, :g} |> transmit(options)
  end

  @doc """
  Record a set metric.

  * `tags`: Add tags to entry (DogStatsD-only)
  """
  def set(member, metric, options \\ [tags: []]) do
    {metric, member, :s} |> transmit(options)
  end

  @doc """
  Record a timer metric.

  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)
  """
  def timer(amount, metric, options \\ [sample_rate: 1, tags: []]) do
    sampling options, fn(rate) ->
      {metric, amount, :ms} |> transmit(options, rate)
    end
  end

  @doc """
  ## Options
  * `sample_rate`: Limit how often the metric is collected
  * `tags`: Add tags to entry (DogStatsD-only)
  """
  def timing(metric, fun, options \\ [sample_rate: 1, tags: []]) do
    sampling options, fn(rate) ->
      {time, value} = :timer.tc(fun)
      amount = time / 1000.0
      # We should hard code the amount when we are in test mode.
      if (Mix.env == :test), do: amount = 1.234
      {metric, amount, :ms} |> transmit(options, rate)
      value
    end
  end

  @doc """
  (DogStatsD-only)
  """
  def histogram(amount, metric, options \\ [sample_rate: 1, tags: []]) do
    sampling options, fn(rate) ->
      {metric, amount, :h} |> transmit(options, rate)
    end
  end

  @doc """
  (DogStatsD-only)
  """
  def histogram_timing(metric, fun, options \\ [sample_rate: 1, tags: []]) do
    sampling options, fn(rate) ->
      {time, value} = :timer.tc(fun)
      amount = time / 1000.0
      # We should hard code the amount when we are in test mode.
      if (Mix.env == :test), do: amount = 1.234
      {metric, amount, :h} |> transmit(options, rate)
      value
    end
  end

  defp sampling(options, fun) when is_list(options) do
    case Keyword.get(options, :sample_rate, 1) do
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

  defp transmit(message, options), do: transmit(message, options, 1)
  defp transmit(message, options, sample_rate) do
    GenServer.cast(__MODULE__, {:transmit, message, options, sample_rate})
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
    ["|@", :io_lib.format('~.2f', [1.0 / sample_rate])]
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

end
