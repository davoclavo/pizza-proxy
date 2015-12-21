defmodule Pizza.Proxy do
  use Plug.Builder
  require Logger
  require IEx

  # plug Plug.Logger
  plug Plug.Static, at: "/pizzas", from: :pizza
  plug :block_localhost_loop
  plug :assign_upstream_url
  plug :set_upstream_response
  plug :change_images_to_pizzas
  plug :send_response

  def block_localhost_loop(conn, _opts) do
    if conn.req_headers["host"] =~ "localhost" do
      halt(conn)
    else
      conn
    end
  end

  # Get upstream request url and assign it
  def assign_upstream_url(conn, _opts) do
    partial_url = ~s(#{conn.scheme}://#{conn.req_headers["host"]}#{conn.request_path})
    url = case conn.query_string do
            ""           -> partial_url
            query_string -> partial_url <> "?" <> query_string
          end

    Logger.debug(url)

    conn
    |> assign(:upstream_url, url)
  end

  # Make request to upstream url
  def set_upstream_response(conn, _opts) do
    url = conn.assigns[:upstream_url]
    method = conn.method |> String.downcase |> String.to_atom
    headers = conn
    |> delete_req_header("accept-encoding") # Don't gzip the upstream response
    |> Map.get(:req_headers)

    {:ok, body, conn} = read_body(conn)

    response = HTTPoison.request!(method, url, body, headers, follow_redirect: true)

    conn
    |> put_normalized_resp_headers(response.headers)
    |> delete_resp_header("content-length") # We might modify the content
    |> delete_resp_header("transfer-encoding") # Don't "chunk" responses
    |> resp(response.status_code, response.body)
  end

  defp put_normalized_resp_headers(conn, []), do: conn
  defp put_normalized_resp_headers(conn, [{header, value} | remaining_headers]) do
    conn
    |> put_resp_header(String.downcase(header), value)
    |> put_normalized_resp_headers remaining_headers
  end

  # Replace all <img src=""> with our own
  # OR proxy all requests that query for .jpg/.gif or Accept application/image
  def change_images_to_pizzas(conn, _opts) do
    case conn.resp_headers["content-type"] do
      "text/html" <> _ ->
        Logger.debug("replacing images!")
        pizza_url = "http://localhost:4000/pizzas/homer.gif"
        new_resp_body = replace_image_urls(conn.resp_body, pizza_url)
        %{conn | resp_body: new_resp_body}
      "image/" <> _ ->
        # TODO: Serve local gif
        # File.read("asdjf/pizza.gif")
        # put content type header "image/blabla"
        conn
      _ ->
        conn
    end
  end

  def replace_image_urls(html_string, url) do
    String.replace(html_string, ~r/(<img[^>]+src=")[^"]+/ium, "\\1#{url}")
  end

  def send_response(conn, _opts) do
    conn
    |> send_resp
    |> halt
  end
end
