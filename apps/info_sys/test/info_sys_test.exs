defmodule InfoSysTest do
  use ExUnit.Case
  alias InfoSys.Result

  # Create a stub TestBackend as we do not want to make network calls to the actual
  # Wolfram Alpha service during tests.
  # Get this stub to return data in the expected format.
  defmodule TestBackend do
    def start_link(query, ref, owner, limit) do
      Task.start_link(__MODULE__, :fetch, [query, ref, owner, limit])
    end

    # query string used to specify which set of results to fetch
    def fetch("result", ref, owner, _limit) do
      send(owner, {:results, ref, [%Result{backend: "test", text: "result"}]})
    end
    def fetch("none", ref, owner, _limit) do
      send(owner, {:results, ref, []})
    end

    def fetch("timeout", _ref, owner, _limit) do
      send(owner, {:backend, self()})
      # simulates a request that takes too long
      :timer.sleep(:infinity)
    end
  end

  test "compute/2 with timeout returns no results and kills workers" do
    # use the fetch parameter to simulate difficult behaviour
    results = InfoSys.compute("timeout", backends: [TestBackend], timeout: 10)
    # ensure 0 results after short 10ms timeout
    assert results == []
    # check that we received the backend_pid, then monitor it for the :DOWN message
    # assert_receive waits 100ms by default, can be configured with a parameter
    assert_receive {:backend, backend_pid}

    ref = Process.monitor(backend_pid)
    # check that code received :DOWN and killed the backend
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}
    # refute_received makes sure there are no more :DOWN or :timedout messages
    # in the inbox. compute was written to clean up after itself, so this checks
    # the cleanup code.
    # Note this is different from refute_receive, which will wait 100ms first.
    refute_received {:DOWN, _, _, _, _}
    refute_received :timedout
  end

  test "compute/2 with backend results" do
    assert [%Result{backend: "test", text: "result"}] =
      InfoSys.compute("result", backends: [TestBackend])
  end

  test "compute/2 with no backend results" do
    assert [] = InfoSys.compute("none", backends: [TestBackend])
  end
end
