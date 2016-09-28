ExStatsD
========

A [statsd](https://github.com/etsy/statsd) client implementation for
Elixir.

## Usage

Add ExStatsD as a dependency for your application.

```elixir
defp deps do
  [{:ex_statsd, ">= 0.5.1"}]
end
```

You should also update your applications list to include statsd:

```elixir
def application do
  [applications: [:ex_statsd]]
end
```

Configure `ex_statsd` using `Mix.Config` as usual (probably in your
`config/`):

```elixir
use Mix.Config

config :ex_statsd,
       host: "your.statsd.host.com",
       port: 1234,
       namespace: "your-app"
```

The defaults are:

 * host: 127.0.0.1
 * port: 8125
 * namespace: nil

The following are the basic metric types. Additional features are
described in "Extensions," below.

### Counters

Counters can be manipulated with `ExStatsD.increment/1` and
`ExStatsD.decrement/1` for simple counts:

```elixir
if passed? do
  ExStatsD.increment("cases.passed")
end
```

```elixir
if cancelled_account? do
  ExStatsD.decrement("users")
end
```

You can also provide a `sample_rate` with `ExStatsD.increment/2` and
`ExStatsD.decrement/2`. For example, in this case an increment for
`cart.added` will only be sent 50% of the time:

```elixir
ExStatsD.increment("cart.added", sample_rate: 0.5)
```

To set a counter explicitly, use `ExStatsD.counter/2`:

```elixir
3 |> ExStatsD.counter("cart.removed")
```

You can also send a `sample_rate`:

```elixir
3 |> ExStatsD.counter("cart.removed", sample_rate: 0.25)
```

Note that the function returns the value (eg, `3` here), making it
suitable for pipelining.

### Timers

Manually timed values can be recorded with `ExStatsD.timer/2`:

```elixir
elapsed_ms = # something manually timed in
elapsed_ms |> ExStatsD.timer("foobar")
```

The value passed to `ExStatsD.timer/2` (eg, `elapsed_ms` here) is
returned from it, making this suitable for pipelining.

For convenience, you can also time a function call with
`ExStatsD.timing/2`:

```elixir
ExStatsD.timing "foo.bar", fn ->
  # Time something
end
```

To sample (ie, 50% of the time), pass a `sample_rate`:

```elixir
ExStatsD.timing "foo.bar", fn ->
  # Time something, some of the time
end, sample_rate: 0.5
```

Note that, regardless of the sample rate, the function is always
called -- it's just not always measured. Also note that the return
value of the measured function is returned, making this suitable for pipelining.

### Sets

A value can be recorded in a set with `ExStatsD.set/2`:

```elixir
user_id |> ExStatsD.set("users")
```

Note that the function returns the value, making it suitable for pipelining.

## Extensions

### Datadog

#### Tags

All metrics support the
[Datadog-specific tags extension](http://docs.datadoghq.com/guides/dogstatsd/#tags)
to StatsD. If you are using DogStatsD, you may provide a `tags`
option, eg:

```elixir
ExStatsD.increment("cart.added", tags: ~w(foo bar))
```

#### Histograms

The [histogram](http://docs.datadoghq.com/guides/dogstatsd/#histograms)
extension to StatsD is supported for DogStatsD:

```elixir
42 |> ExStatsD.histogram("database.query.time", tags: ["db", "perf"])
```

Note that the function returns the value, making it suitable for pipelining.

#### Histogram Timing

A histogram version of the [ExStatsD.timing](#timers) function is
supported for DogStatsD.

```elixir
ExStatsD.histogram_timing "foo.bar", fn ->
  # Time something
end
```

### Decorators

The decorators allow you to quickly and easily time function calls in
your code. Simply replace `def` with `deftimed` for those functions
you wish to time.

```elixir
defmodule MyModule.Data do
  use ExStatsD.Decorator

  deftimed slow_function do
    # This is a suspect function we wish to time.
  end

end
```

Now all calls to `MyModule.Data.slow_function/0` will be timed and
reported to your statsd server. By default the metric key used for
each call will be `PREFIX.function_call.MODULE.FUNCTION_ARITY`. So in
this example it would have been
`function_call.mymodule.data.slow_function_0`.

You can change the metric name by setting the `@metric` attribute
ahead of the function. The metric will apply to other function
definitions of the same arity unless specifically changed again. Other
following functions of different name or arity will use the default.

```elixir
deftimed init, do: nil # PREFIX.function_call.mymodule.data.init_0

@metric "trace.some_function"
deftimed some_function(1), do: nil # PREFIX.trace.some_function
deftimed some_function(2), do: nil # PREFIX.trace.some_function

@metric "trace.some_function_catchall"
deftimed some_function(x) when is_list(x), do: nil # PREFIX.trace.some_function_catchall
deftimed some_function(x), do: nil # PREFIX.trace.some_function_catchall

deftimed some_function(x,y), do: nil # PREFIX.function_call.mymodule.data.some_function_2
```

You can set options using the `@metric_options` attribute. This follows the same rules as with the `@metric` example abobe.

Here we use Datadog's "tag" extension to StatD:

```elixir
@metric_options [tags: ["basic"]]
deftimed some_function(), do: nil
```

There are 2 global options available. Both will apply to all functions that follow it unless locally overridden.

 * `@default_metric_options`: Metric options to use unless overridden with `@metric_options`. Defaults to [].
 * `@use_histogram`: Send results using histograms instead of gauges. For use with Datadog's DogStatD. Defaults to false.

## Starting your own ExStatsD Server

There may be use cases where you need several `ExStatsD` instances. You may have several `namespaces` you need to send stats to, or maybe you have multiple statsd services you need to publish to.

To achieve this you can manually start a `ExStatsD` instance.

```elixir
  {:ok, _first_pid} = ExStatsD.start_link([name: :first, namespace: "first.namespace"])

  {:ok, _second_pid} = ExStatsD.start_link([name: :second, namespace: "second.namespace"])

  ExStatsD.increment("the.thing", name: :first) # nil
  ExStatsD.increment("another.thing", name: :second) # nil
```

Of course, it's your own responsibility to supervise these servers.

To do that, you can use [Supervisors](http://elixir-lang.org/docs/stable/elixir/Supervisor.html)

```elixir
defmodule StatsDSupervisor do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [])
  end

  def init(_) do
    children = [
      worker(ExStatsD, [[name: :first_name, namespace: "first.namespace"]], [id: "first_id"]),
      worker(ExStatsD, [[name: :second_name, namespace: "second.namespace"]], [id: "second_id"])
    ]

    options = [
      strategy: :one_for_one, name: StatsDSupervisor
    ]

    supervise(children, options)
  end
end
```


The items that can be overridden include
* port
* host
* namespace
* sink

## License

The MIT License (MIT)

Copyright (c) 2014 CargoSense, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
