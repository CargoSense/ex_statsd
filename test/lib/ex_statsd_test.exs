defmodule ExStatsDTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = ExStatsD.start_link
    {:ok, pid: pid}
  end

  test "count (in pipeline)" do
    values = 1..100 |> ExStatsD.count("items")
    assert sent == ["test.items:100|c"]
    assert values == 1..100
  end

  test "counter (in pipeline)" do
    value = 3 |> ExStatsD.counter("items")
    assert sent == ["test.items:3|c"]
    assert value == 3
  end

  test "gauge (in pipeline)" do
    value = 3 |> ExStatsD.gauge("items")
    assert sent == ["test.items:3|g"]
    assert value == 3
  end

  test "increment" do
    ExStatsD.increment("events")
    assert sent == ["test.events:1|c"]
    ExStatsD.increment("events", sample_rate: 0.15)
  end

  test "increment with tags" do
    ExStatsD.increment("events", tags: ["foo", "bar"])
    assert sent == ["test.events:1|c|#foo,bar"]
    ExStatsD.increment("events", sample_rate: 0.15)
  end

  test "decrement" do
    ExStatsD.decrement("events")
    assert sent == ["test.events:-1|c"]
    ExStatsD.decrement("events", sample_rate: 0.15)
  end

  test "decrement with tags" do
    ExStatsD.decrement("events", tags: ["foo", "bar"])
    assert sent == ["test.events:-1|c|#foo,bar"]
    ExStatsD.decrement("events", sample_rate: 0.15)
  end

  test "timing always calls" do
    values = Enum.map 1..100, fn n -> ExStatsD.timing("foo.bar", fn -> n * 2 end, sample_rate: 0.01) end
    assert values == Enum.map(1..100, fn n -> n * 2 end)
  end

  test "timer" do
    value = 12 |> ExStatsD.timer("fun.elapsed")
    assert sent == ["test.fun.elapsed:12|ms"]
    assert value == 12
  end

  test "timer with tags" do
    value = 12 |> ExStatsD.timer("fun.elapsed", tags: ["foo", "bar"])
    assert sent == ["test.fun.elapsed:12|ms|#foo,bar"]
    assert value == 12
  end

  test "gauge" do
    value = 11 |> ExStatsD.gauge("fun.thing")
    assert sent == ["test.fun.thing:11|g"]
    assert value == 11
  end

  test "gauge with tags" do
    value = 11 |> ExStatsD.gauge("fun.thing", tags: ["foo", "bar"])
    assert sent == ["test.fun.thing:11|g|#foo,bar"]
    assert value == 11
  end

  test "set" do
    value = 1 |> ExStatsD.set("users.ids")
    assert sent == ["test.users.ids:1|s"]
    assert value == 1
  end

  test "set with tags" do
    value = 1 |> ExStatsD.set("users.ids", tags: ["foo", "bar"])
    assert sent == ["test.users.ids:1|s|#foo,bar"]
    assert value == 1
  end

  test "histogram" do
    value = 42 |> ExStatsD.histogram("histogram")
    assert sent == ["test.histogram:42|h"]
    assert value == 42
  end

  test "histogram with tags" do
    value = 42 |> ExStatsD.histogram("histogram", tags: ["foo", "bar"])
    assert sent == ["test.histogram:42|h|#foo,bar"]
    assert value == 42
  end

  test "stop", %{pid: pid} do
    assert :ok == ExStatsD.stop
    refute Process.alive?(pid)
  end

  test "flush" do
    assert :ok == ExStatsD.flush
  end

  defp sent, do: :sys.get_state(ExStatsD).sink

end
