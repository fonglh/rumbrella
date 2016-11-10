defmodule InfoSys.Wolfram do
  import SweetXml   # helps parse the XML received
  alias InfoSys.Result    # has the struct for the results we'll use

  # Less stuff than a GenServer, which holds both computation and state.
  # Agents manage state.
  # Tasks are simple processes that execute the given function.
  def start_link(query, query_ref, owner, limit) do
    Task.start_link(__MODULE__, :fetch, [query, query_ref, owner, limit])
  end

  # called from start_link
  def fetch(query_str, query_ref, owner, _limit) do
    query_str
    |> fetch_xml()
    |> xpath(~x"/queryresult/pod[contains(@title, 'Result') or
                                 contains(@title, 'Definitions')]
                            /subpod/plaintext/text()")
    |> send_results(query_ref, owner)
  end

  # 2 versions of send_results, depending on whether we get results back or not
  # Match on the 1st argument. On nil, send an empty list.
  # Else build a `result` struct with expected results and score, then build a
  # tuple with our results and send it back to `owner`.
  defp send_results(nil, query_ref, owner) do
    send(owner, {:results, query_ref, []})
  end
  defp send_results(answer, query_ref, owner) do
    # pid for the caller is in `owner`
    results = [%Result{backend: "wolfram", score: 95, text: to_string(answer)}]
    send(owner, {:results, query_ref, results})
  end

  # contact WolframAlpha with the query string that interests us.
  # :httpc is from Erlang's standard library
  # Get http client from the environment, so we can use a stubbed one for tests
  @http Application.get_env(:info_sys, :wolfram) [:http_client] || :httpc
  defp fetch_xml(query_str) do
    {:ok, {_, _, body}} = @http.request(
      String.to_char_list("http://api.wolframalpha.com/v2/query" <>
        "?appid=#{app_id()}" <>
        "&input=#{URI.encode(query_str)}&format=plaintext"))
    body
  end

  # extracts API key from app configuration
  defp app_id, do: Application.get_env(:info_sys, :wolfram)[:app_id]
end
