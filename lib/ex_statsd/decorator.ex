defmodule ExStatsD.Decorator do
  defmacro __using__(_opts) do
    quote do
      import ExStatsD.Decorator
      @use_histogram false
      @default_metric_options []
    end
  end

  defmacro deftimed(head, body \\ nil) do
    {fun_name, args_ast} = Macro.decompose_call(head)
    arg_length = length(args_ast)
    quote do
      @ex_statsd_metric metric_name(__MODULE__, unquote(fun_name), unquote(arg_length))
      @ex_statsd_options metric_options(__MODULE__, unquote(fun_name), unquote(arg_length))
      @ex_statsd_timing_function use_histogram(__MODULE__)
      def unquote(head) do
        result = Kernel.apply(ExStatsD, @ex_statsd_timing_function, [@ex_statsd_metric, fn ->
          unquote(body[:do])
        end, @ex_statsd_options])
        result
      end
    end
  end

  def use_histogram(module) do
    if Module.get_attribute(module, :use_histogram) do
      :histogram_timing
    else
      :timing
    end
  end

  @doc false
  def metric_name(module, fun_name, arg_length) do
    function_id = "#{fun_name}_#{arg_length}"
    statsd_metric = Module.get_attribute(module, :metric)
    if (statsd_metric) do
      update_metric_name(module, function_id, statsd_metric)
    else
      get_metric_name(module, function_id)
    end
  end

  defp get_metric_name(module, function_id) do
    metric_atom = String.to_atom("#{function_id}_metric")
    function_metric = Module.get_attribute(module, metric_atom)
    if function_metric do
      function_metric
    else
      default = String.downcase("function_call.#{module}.#{function_id}")
      Module.put_attribute(module, metric_atom, default)
      default
    end
  end

  defp update_metric_name(module, function_id, metric_name) do
    metric_atom = String.to_atom("#{function_id}_metric")
    Module.put_attribute(module, metric_atom, metric_name)
    Module.put_attribute(module, :metric, nil)
    metric_name
  end

  @doc false
  def metric_options(module, fun_name, arg_length) do
    function_id = "#{fun_name}_#{arg_length}"
    statsd_options = Module.get_attribute(module, :metric_options)
    if (statsd_options) do
      update_metric_options(module, function_id, statsd_options)
    else
      get_metric_options(module, function_id)
    end
  end

  defp get_metric_options(module, function_id) do
    options_atom = String.to_atom("#{function_id}_metric_options")
    function_options = Module.get_attribute(module, options_atom)
    if function_options do
      function_options
    else
      defaults = Module.get_attribute(module, :default_metric_options)
      Module.put_attribute(module, options_atom, defaults)
      defaults
    end
  end

  defp update_metric_options(module, function_id, options) do
    options_atom = String.to_atom("#{function_id}_metric_options")
    Module.put_attribute(module, options_atom, options)
    Module.put_attribute(module, :metric_options, nil)
    options
  end

end
