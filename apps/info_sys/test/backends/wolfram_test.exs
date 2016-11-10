defmodule InfoSys.Backends.WolframTest do
  use ExUnit.Case, async: true
  alias InfoSys.Wolfram

  test "make request, reports results, then terminates" do
    ref = make_ref()
    # spawn a backend
    {:ok, pid} = Wolfram.start_link("1 + 1", ref, self(), 1)
    # make sure backend terminates after work is complete.
    Process.monitor(pid)

    # ensure results are correct, and that the process terminates normally
    assert_receive {:results, ^ref, [%InfoSys.Result{text: "2"}]}
    assert_receive {:DOWN, _ref, :process, ^pid, :normal}
  end

  test "no query results returns an empty list" do
    ref = make_ref()
    {:ok, pid} = Wolfram.start_link("none", ref, self, 1)
    Process.monitor(pid)

    assert_receive {:results, ^ref, []}
  end
end
