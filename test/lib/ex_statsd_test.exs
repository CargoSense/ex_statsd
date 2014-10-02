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

  test "decrement" do
    ExStatsD.decrement("events")
    assert sent == ["test.events:-1|c"]
    ExStatsD.decrement("events", sample_rate: 0.15)
  end

  test "timer" do
    12 |> ExStatsD.timer("fun.elapsed")
    assert sent == ["test.fun.elapsed:12|ms"]
  end

  test "gauge" do
    11 |> ExStatsD.gauge("fun.thing")
    assert sent == ["test.fun.thing:11|g"]
  end

  test "set" do
    1 |> ExStatsD.set("users.ids")
    assert sent == ["test.users.ids:1|s"]
  end

  defp sent, do: :sys.get_state(ExStatsD).sink

end
