defmodule ExStatsD.Config do
  @moduledoc """
  This module handles fetching values from the config with some additional niceties
  """

  @doc """
  Fetches a value from the config, or from the environment if {:system, "VAR"}
  is provided.
  An optional default value can be provided if desired.
  ## Example
  iex> {test_var, expected_value} = System.get_env |> Enum.take(1) |> List.first
  ...> Application.put_env(:ex_statsd, :test_var, {:system, test_var})
  ...> ^expected_value = #{__MODULE__}.get(:ex_statsd, :test_var)
  ...> :ok
  :ok
  iex> Application.put_env(:ex_statsd, :test_var2, 1)
  ...> 1 = #{__MODULE__}.get(:ex_statsd, :test_var2)
  1
  iex> :default = #{__MODULE__}.get(:ex_statsd, :missing_var, :default)
  :default
  """
  @spec get(atom, term | nil) :: term
  def get(key, default \\ nil) when is_atom(key) do
    app = :ex_statsd

    value = case Application.get_env(app, key) do
      {:system, env_var} -> System.get_env(env_var)
      value -> value
    end

    case value do
      nil -> default
      value -> value
    end
  end
end