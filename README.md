ExStatsD
========

A [statsd](https://github.com/etsy/statsd) client implementation for
Elixir.

## Usage

Add ExStatsD as a dependency for your application.

```elixir
defp deps do
  [{:ex_statsd, ">= 0.1.0"}]
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

### Timers

Manually timed values can be recorded with `ExStatsD.timer/2`:

```elixir
elapsed_ms = # something manually timed in
elapsed_ms |> ExStatsD.timer("foobar")
```

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

Note that (as of v0.3.0), regardless of the sample rate the function
is always called -- it's just not always measured.

### Sets

A value can be recorded in a set with `ExStatsD.set/2`:

```elixir
user_id |> ExStatsD.set("users")
```

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
