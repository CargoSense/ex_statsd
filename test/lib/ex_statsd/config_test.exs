defmodule ExStatsD.ConfigTest do
  use ExUnit.Case

  test "generate: default values merged with ex_statsd app config" do
    assert ExStatsD.Config.generate == %{
      port: 8125,
      host: {127, 0, 0, 1},
      namespace: "test",
      sink: [],
      socket: nil,
      tags: []
    }
  end

  test "generate: when using system env vars" do
    with_sys "foo,bar,baz", fn ->
      with_app :tags, {:system, var}, fn ->
        config = ExStatsD.Config.generate
        assert config[:tags] == ~w(foo bar baz)
      end
    end
  end

  test "generate: when system var is empty" do
    with_app :tags, {:system, var}, fn ->
      config = ExStatsD.Config.generate
      assert config[:tags] == []
    end
  end

  test "generate: when system var is empty but default was given" do
    with_app :tags, {:system, var, ~w(db perf)}, fn ->
      config = ExStatsD.Config.generate
      assert config[:tags] == ~w(db perf)
    end
  end

  test "generate: when syustem var is present & default given" do
    with_sys "foo,bar,baz", fn ->
      with_app :tags, {:system, var, ~w(db perf)}, fn ->
        config = ExStatsD.Config.generate
        assert config[:tags] == ~w(foo bar baz)
      end
    end
  end

  defp var, do: "5689bec05b9b4acba45ddc2a0a61d693_exstasd_test"

  defp with_sys(value, func) do
    System.put_env(var, value)
    func.()
    System.delete_env(var)
  end

  defp with_app(name, val, func) do
    old = Application.get_env(:ex_statsd, name)
    Application.put_env(:ex_statsd, name, val)
    func.()
    Application.put_env(:ex_statsd, name, old)
  end
end
