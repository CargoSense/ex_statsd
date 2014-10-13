defmodule ExStatsDTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = ExStatsD.start_link
    {:ok, pid: pid}
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

  test "timer" do
    12 |> ExStatsD.timer("fun.elapsed")
    assert sent == ["test.fun.elapsed:12|ms"]
  end

  test "timer with tags" do
    12 |> ExStatsD.timer("fun.elapsed", tags: ["foo", "bar"])
    assert sent == ["test.fun.elapsed:12|ms|#foo,bar"]
  end

  test "gauge" do
    11 |> ExStatsD.gauge("fun.thing")
    assert sent == ["test.fun.thing:11|g"]
  end

  test "gauge with tags" do
    11 |> ExStatsD.gauge("fun.thing", tags: ["foo", "bar"])
    assert sent == ["test.fun.thing:11|g|#foo,bar"]
  end

  test "set" do
    1 |> ExStatsD.set("users.ids")
    assert sent == ["test.users.ids:1|s"]
  end

  test "set with tags" do
    1 |> ExStatsD.set("users.ids", tags: ["foo", "bar"])
    assert sent == ["test.users.ids:1|s|#foo,bar"]
  end

  test "histogram" do
    42 |> ExStatsD.histogram("histogram")
    assert sent == ["test.histogram:42|h"]
  end

  test "histogram with tags" do
    42 |> ExStatsD.histogram("histogram", tags: ["foo", "bar"])
    assert sent == ["test.histogram:42|h|#foo,bar"]
  end

  defp sent, do: :sys.get_state(ExStatsD).sink

end
