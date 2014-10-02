defmodule ExStatsD.Application do
  use Application

  def start(_type, _args) do
    ExStatsD.start_link
  end
end
