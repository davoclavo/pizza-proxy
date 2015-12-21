defmodule Pizza.ProxyTest do
  use ExUnit.Case, async: true
  use Plug.Test

  @opts Pizza.Proxy.init([])

  defp create_conn do
    conn(:get, "/")
    |> put_req_header("host", "imgur.com")
  end

  @html_with_images """
<html>
  <body>
    <img alt="" src="//i.imgur.com/tJwB3BSb.jpg" />
  </body>
</html>
  """

  test "replaces img src" do
    replaced_html = Pizza.Proxy.replace_image_urls(@html_with_images, "http://elixir.pizza/logo.jpg")
    refute replaced_html == @html_with_images
    assert String.contains? replaced_html, "elixir.pizza"

  end

  test "proxy works" do
    conn = create_conn
    |> Pizza.Proxy.call(@opts)

    assert conn.state == :sent
    assert conn.status == 200
    assert conn.resp_body =~ ~r/riffsy/
  end
end
