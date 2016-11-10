defmodule InfoSys.Test.HTTPClient do
  # stubs the request function and returns fake results
  @wolfram_xml File.read!("test/fixtures/wolfram.xml")
  def request(url) do
    url = to_string(url)

    cond do
      # Return xml contents if 1+1 is in the query string, else return fake request for empty
      # XML results.
      String.contains?(url, "1%20+%201") -> {:ok, {[], [], @wolfram_xml}}
      true -> {:ok, {[], [], "<queryresult></queryresult>"}}
    end
  end
end
