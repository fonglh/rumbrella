defmodule InfoSys do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    InfoSys.Supervisor.start_link()
  end

  # Generic module to spawn computations for queries.
  # The backends are their own processes, but InfoSys isn't.
  @backends [InfoSys.Wolfram]

  # Struct for holding each search result
  defmodule Result do
    # score is for relevance
    defstruct score: 0, text: nil, url: nil, backend: nil
  end

  # This is a proxy which calls `start_link` for the specific backend
  def start_link(backend, query, query_ref, owner, limit) do
    backend.start_link(query, query_ref, owner, limit)
  end

  def compute(query, opts \\ []) do
    limit = opts[:limit] || 10
    backends = opts[:backends] || @backends

    backends
    |> Enum.map(&spawn_query(&1, query, limit))
    |> await_results(opts)
    |> Enum.sort(&(&1.score >= &2.score))
    |> Enum.take(limit)
  end

  defp spawn_query(backend, query, limit) do
    query_ref = make_ref()
    opts = [backend, query, query_ref, self(), limit]
    {:ok, pid} = Supervisor.start_child(InfoSys.Supervisor, opts)
    monitor_ref = Process.monitor(pid)
    {pid, monitor_ref, query_ref}
  end

  defp await_results(children, opts) do
    timeout = opts[:timeout] || 5000
    timer = Process.send_after(self(), :timedout, timeout)
    results = await_result(children, [], :infinity)
    cleanup(timer)

    results
  end

  defp await_result([head|tail], acc, timeout) do
    {pid, monitor_ref, query_ref} = head

    receive do
      # valid result, drop the monitor.
      # [:flush] guarantees that the :DOWN message is removed from the inbox
      # in case it's delivered before we drop the monitor.
      {:results, ^query_ref, results} ->
        Process.demonitor(monitor_ref, [:flush])
        await_result(tail, results ++ acc, timeout)
      # match on monitor_ref, because :DOWN messages come from the monitor
      # and not the GenServer.
      # Recurse without adding to the accumulator.
      {:DOWN, ^monitor_ref, :process, ^pid, _reason} ->
        await_result(tail, acc, timeout)
      # kill the backend we are waiting on and move to the next one.
      # use a timeout of 0 for subsequent calls.
      :timedout ->
        kill(pid, monitor_ref)
        await_result(tail, acc, 0)

    # setting timeout to 0 triggers this branch for subsequent backends unless a reply
    # is already in the process inbox.
    after
      timeout ->
        kill(pid, monitor_ref)
        await_result(tail, acc, 0)
    end
  end

  # base case, ends recursion when list has been processed.
  defp await_result([], acc, _) do
    acc
  end

  # Removes the monitor and sends the :kill message to the backend process.
  defp kill(pid, ref) do
    Process.demonitor(ref, [:flush])
    Process.exit(pid, :kill)
  end

  # cancel the timer in case it wasn't yet triggered
  # flush :timedout message to inbox if it was already sent.
  defp cleanup(timer) do
    :erlang.cancel_timer(timer)
    receive do
      :timed_out -> :ok

    after
      0 -> :ok
    end
  end
end
