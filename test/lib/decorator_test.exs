defmodule DecoratorTest do
  use ExUnit.Case, async: false

  defmodule DecoratedModule do
    use ExStatsD.Decorator

    def_timed simple, do: nil

    @metric "custom_key"
    def_timed custom_name, do: nil

    def_timed custom_name_gone, do: nil

    @metric "multi_0_or_1"
    def_timed multi(0), do: 0
    def_timed multi(1), do: 1
    @metric "multi_other"
    def_timed multi(x), do: x

    @metric_options [tags: [:mytag]]
    def_timed with_options, do: nil
    def_timed options_gone, do: nil

    @metric_options [tags: [:options_fall_through]]
    def_timed multi_options(0), do: 0
    def_timed multi_options(1), do: 1
    @metric_options [tags: [:options_get_changed]]
    def_timed multi_options(x), do: x

    @use_histogram true
    def_timed multi_attrs(x, y), do: {x, y}
    def_timed multi_attrs(x, y, z), do: {x, y, z}

    @default_metric_options [tags: ["mine"]]
    def_timed ignored_attr(_x), do: nil
    def_timed unbound_attr(_), do: nil

    def_timed guarded(x) when is_list(x), do: nil

  end

  setup do
    {:ok, pid} = ExStatsD.start_link
    # Lets cheat for sampling here. Setting the seed like this should set the
    # 3 next calls to :random.uniform as 0.01, 0.89 and 0.11
    :random.seed(0, 0, 0)
    {:ok, pid: pid}
  end

  @prefix "test.function_call.elixir.decoratortest.decoratedmodule."

  test "basic wrapper with defaults" do
    DecoratedModule.simple
    expected = [@prefix<>"simple_0:1.234|ms"]
    assert sent == expected
  end

  test "custom metric name" do
    DecoratedModule.custom_name
    expected = ["test.custom_key:1.234|ms"]
    assert sent == expected
  end

  test "custom metric name does not leak to next function" do
    DecoratedModule.custom_name
    DecoratedModule.custom_name_gone
    expected = [
      @prefix<>"custom_name_gone_0:1.234|ms",
      "test.custom_key:1.234|ms"
    ]
    assert sent == expected
  end

  test "custom metric name falling to next in match unless changed" do
    DecoratedModule.multi(0)
    DecoratedModule.multi(1)
    DecoratedModule.multi(2)
    expected = [
      "test.multi_other:1.234|ms",
      "test.multi_0_or_1:1.234|ms",
      "test.multi_0_or_1:1.234|ms"
    ]
    assert sent == expected
  end

  test "tags are set and don't leak" do
    DecoratedModule.with_options
    DecoratedModule.options_gone
    expected = [
      @prefix<>"options_gone_0:1.234|ms",
      @prefix<>"with_options_0:1.234|ms|#mytag"
    ]
    assert sent == expected
  end

  test "tags fall through and get updated" do
    DecoratedModule.multi_options(0)
    DecoratedModule.multi_options(1)
    DecoratedModule.multi_options(2)
    expected = [
      @prefix<>"multi_options_1:1.234|ms|#options_get_changed",
      @prefix<>"multi_options_1:1.234|ms|#options_fall_through",
      @prefix<>"multi_options_1:1.234|ms|#options_fall_through",
    ]
    assert sent == expected
  end

  test "send using histogram when enabled in all following functions" do
    DecoratedModule.multi_attrs(1, 2)
    DecoratedModule.multi_attrs(1, 2, 3)
    expected = [
      @prefix<>"multi_attrs_3:1.234|h",
      @prefix<>"multi_attrs_2:1.234|h"
    ]
    assert sent == expected
  end

  test "default options can be changed" do
    DecoratedModule.ignored_attr(1)
    DecoratedModule.unbound_attr(2)
    expected = [
      @prefix<>"unbound_attr_1:1.234|h|#mine",
      @prefix<>"ignored_attr_1:1.234|h|#mine"
    ]
    assert sent == expected
  end

  defp sent, do: :sys.get_state(ExStatsD).sink

end
