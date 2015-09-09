defmodule ExStatsD.Application do
  use Application

  def start(_type, _args) do
    ExStatsD.Supervisor.start_link([])
  end
end
