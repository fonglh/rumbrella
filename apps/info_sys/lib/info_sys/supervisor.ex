defmodule InfoSys.Supervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    # temporary means child is never restarted.
    # for this system, we're calling an external API in parallel
    # and will just take as many results as we can get.
    #
    # only child now is a GenServer worker defined in InfoSys
    children = [
      worker(InfoSys, [], restart: :temporary)
    ]

    # simple one for one doesn't start any children.
    # waits for us to explicitly ask it to start a child, then handles
    # crashes like :one_for_one would.
    supervise children, strategy: :simple_one_for_one
  end
end
