defmodule Mint.UnsafeProxyTest do
  use ExUnit.Case, async: true
  import Mint.HTTP1.TestHelpers
  alias Mint.UnsafeProxy
  alias Mint.HTTP

  @moduletag :proxy

  test "200 response - http://httpbin.org" do
    assert {:ok, conn} =
             UnsafeProxy.connect({:http, "localhost", 8888}, {:http, "httpbin.org", 80})

    assert {:ok, conn, request} = UnsafeProxy.request(conn, "GET", "/", [], nil)
    assert {:ok, _conn, responses} = receive_stream(conn)

    assert [status, headers | responses] = responses
    assert {:status, ^request, 200} = status
    assert {:headers, ^request, headers} = headers
    assert is_list(headers)
    assert merge_body(responses, request) =~ "httpbin"
  end

  test "407 response - Mint.HTTP.connect with proxy missing authentication" do
    assert {:ok, conn} =
             HTTP.connect(:http, "httpbin.org", 80, proxy: {:http, "localhost", 8889, []})

    assert {:ok, conn, request} = HTTP.request(conn, "GET", "/", [], nil)
    assert {:ok, _conn, responses} = receive_stream(conn)
    assert [status, _headers | _responses] = responses
    assert {:status, ^request, 407} = status
  end

  test "401 response - Mint.HTTP.connect with proxy using invalid authentication" do
    invalid_auth64 = Base.encode64("test:wrong_password")

    assert {:ok, conn} =
             HTTP.connect(:http, "httpbin.org", 80,
               proxy: {:http, "localhost", 8889, []},
               proxy_headers: [{"proxy-authorization", "basic #{invalid_auth64}"}]
             )

    assert {:ok, conn, request} = HTTP.request(conn, "GET", "/", [], nil)
    assert {:ok, _conn, responses} = receive_stream(conn)
    assert [status, _headers | _responses] = responses
    assert {:status, ^request, 401} = status
  end

  test "200 response - Mint.HTTP.connect with proxy using valid authentication" do
    auth64 = Base.encode64("test:password")

    assert {:ok, conn} =
             HTTP.connect(:http, "httpbin.org", 80,
               proxy: {:http, "localhost", 8889, []},
               proxy_headers: [{"proxy-authorization", "basic #{auth64}"}]
             )

    assert {:ok, conn, request} = HTTP.request(conn, "GET", "/", [], nil)
    assert {:ok, _conn, responses} = receive_stream(conn)
    assert [status, headers | responses] = responses
    assert {:status, ^request, 200} = status
    assert {:headers, ^request, headers} = headers
    assert is_list(headers)
    assert merge_body(responses, request) =~ "httpbin"
  end
end
