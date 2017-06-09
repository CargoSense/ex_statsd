defmodule ExStatsDTest do
  use ExUnit.Case

  describe "with non-default options" do
    test "override name through options" do
      name = :dog_data
      options = [name: name]

      {:ok, pid} = ExStatsD.start_link(options)

      assert Process.whereis(:dog_data) === pid
    end

    test "override port through options" do
      port = 8080
      options = [port: port]

      {:ok, _pid} = ExStatsD.start_link(options)

      assert state().port == port
    end

    test "override host through options" do
      host = "the_thing"
      options = [host: host]

      {:ok, _pid} = ExStatsD.start_link(options)

      assert state().host == String.to_atom(host)
    end

    test "override namespace through options" do
      namespace = "a_good_namespace"
      options = [namespace: namespace]

      {:ok, _pid} = ExStatsD.start_link(options)

      assert state().namespace == namespace
    end

    test "override sink through options" do
      sink = "everything_except_the_kitchen_sink"
      options = [sink: sink]

      {:ok, _pid} = ExStatsD.start_link(options)

      assert state().sink == sink
    end

    test "override root tags through options" do
      tags = ["env:prod"]
      options = [tags: tags]

      {:ok, _pid} = ExStatsD.start_link(options)

      assert state().tags == tags
    end

    test "transmits data through correct server" do
      options = [name: :the_name]
      {:ok, _pid} = ExStatsD.start_link(options)

      _values = 1..100 |> ExStatsD.count("items", options)

      assert sent(:the_name) == ["test.items:100|c"]
    end
  end

  describe "with default options" do
    setup do
      {:ok, pid} = ExStatsD.start_link
      {:ok, pid: pid}
    end

    test "count (in pipeline)" do
      values = 1..100 |> ExStatsD.count("items")
      assert sent() == ["test.items:100|c"]
      assert values == 1..100
    end

    test "counter (in pipeline)" do
      value = 3 |> ExStatsD.counter("items")
      assert sent() == ["test.items:3|c"]
      assert value == 3
    end

    test "gauge (in pipeline)" do
      value = 3 |> ExStatsD.gauge("items")
      assert sent() == ["test.items:3|g"]
      assert value == 3
    end

    test "increment" do
      ExStatsD.increment("events")
      assert sent() == ["test.events:1|c"]
      ExStatsD.increment("events", sample_rate: 0.15)
    end

    test "increment with tags" do
      ExStatsD.increment("events", tags: ["foo", "bar"])
      assert sent() == ["test.events:1|c|#foo,bar"]
      ExStatsD.increment("events", sample_rate: 0.15)
    end

    test "decrement" do
      ExStatsD.decrement("events")
      assert sent() == ["test.events:-1|c"]
      ExStatsD.decrement("events", sample_rate: 0.15)
    end

    test "decrement with tags" do
      ExStatsD.decrement("events", tags: ["foo", "bar"])
      assert sent() == ["test.events:-1|c|#foo,bar"]
      ExStatsD.decrement("events", sample_rate: 0.15)
    end

    test "timing always calls" do
      values = Enum.map 1..100, fn n -> ExStatsD.timing("foo.bar", fn -> n * 2 end, sample_rate: 0.01) end
      assert values == Enum.map(1..100, fn n -> n * 2 end)
    end

    test "timer" do
      value = 12 |> ExStatsD.timer("fun.elapsed")
      assert sent() == ["test.fun.elapsed:12|ms"]
      assert value == 12
    end

    test "timer with tags" do
      value = 12 |> ExStatsD.timer("fun.elapsed", tags: ["foo", "bar"])
      assert sent() == ["test.fun.elapsed:12|ms|#foo,bar"]
      assert value == 12
    end

    test "gauge" do
      value = 11 |> ExStatsD.gauge("fun.thing")
      assert sent() == ["test.fun.thing:11|g"]
      assert value == 11
    end

    test "gauge with tags" do
      value = 11 |> ExStatsD.gauge("fun.thing", tags: ["foo", "bar"])
      assert sent() == ["test.fun.thing:11|g|#foo,bar"]
      assert value == 11
    end

    test "set" do
      value = 1 |> ExStatsD.set("users.ids")
      assert sent() == ["test.users.ids:1|s"]
      assert value == 1
    end

    test "set with tags" do
      value = 1 |> ExStatsD.set("users.ids", tags: ["foo", "bar"])
      assert sent() == ["test.users.ids:1|s|#foo,bar"]
      assert value == 1
    end

    test "histogram" do
      value = 42 |> ExStatsD.histogram("histogram")
      assert sent() == ["test.histogram:42|h"]
      assert value == 42
    end

    test "histogram with tags" do
      value = 42 |> ExStatsD.histogram("histogram", tags: ["foo", "bar"])
      assert sent() == ["test.histogram:42|h|#foo,bar"]
      assert value == 42
    end

    test "flush" do
      assert :ok == ExStatsD.flush
    end
  end

  describe "datadog events" do

    setup do
      {:ok, pid} = ExStatsD.start_link
      {:ok, pid: pid}
    end

    test "event" do
      value = ExStatsD.event("oops","some data")
      assert sent() == ["_e{4,9}:oops|some data"]
      assert value == "oops"
    end

    test "event with options" do
      value = ExStatsD.event("foo","bar\nbaz", alert_type: :error, priority: :low, aggregation_key: "moo", hostname: "x", tags: ["foo:bar"])
      assert sent() == [~S(_e{3,8}:foo|bar\nbaz|p:low|t:error|k:moo|h:x|#foo:bar)]
      assert value == "foo"
    end

    test "flush" do
      assert :ok == ExStatsD.flush
    end

  end

  defp state(name \\ ExStatsD) do
    :sys.get_state(name)
  end

  defp sent(name \\ExStatsD), do: state(name).sink

end
