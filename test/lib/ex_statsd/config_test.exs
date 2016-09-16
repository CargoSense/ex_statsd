defmodule ExStatsD.ConfigTest do
  use ExUnit.Case

  test "generate: return default values merged with ex_statsd app config" do
    assert ExStatsD.Config.generate == %{port: 8125, host: {127, 0, 0, 1}, namespace: "test", sink: [], socket: nil}
  end
end
