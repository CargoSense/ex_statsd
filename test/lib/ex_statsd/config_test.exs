defmodule ExStatsD.ConfigTest do
  alias ExStatsD.Config
  use ExUnit.Case, async: false

  test "reads application value" do
    Application.put_env(:ex_statsd, :key, "APPLICATION_VALUE")
    value = Config.get(:key)
    assert value == "APPLICATION_VALUE"
    Application.delete_env(:ex_statsd, :key)
  end

  test "reads application value with default" do
    value = Config.get(:key, "DEFAULT_VALUE")
    assert value == "DEFAULT_VALUE"
  end

  test "reads system value" do
    System.put_env("SYSTEM_KEY", "SYSTEM_VALUE")
    Application.put_env(:ex_statsd, :key, {:system, "SYSTEM_KEY"})
    value = Config.get(:key)
    assert value == "SYSTEM_VALUE"

    System.delete_env("SYSTEM_KEY")
    Application.delete_env(:ex_statsd, :key)
  end
end
