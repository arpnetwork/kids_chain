alias KidsChain.{ChainAgent, DB}

require DB

defmodule KidsChain.Router do
  @moduledoc false

  use Plug.Router

  plug Plug.Parsers, parsers: [:urlencoded]
  plug :match
  plug :dispatch

  post "/users" do
    uid = conn.params["uid"]
    inviter = conn.params["inviter"]

    unless is_nil(uid) || is_nil(inviter) do
      u = conn.params |> normalize() |> Map.take([:uid, :inviter, :content, :email, :address])

      case ChainAgent.create(u) do
        {:ok, _} -> send_resp(conn, 200, "OK")
        _ -> send_forbidden(conn)
      end
    else
      send_forbidden(conn)
    end
  end

  post "/users/:uid" do
    uid = conn.params["uid"]

    unless is_nil(uid) do
      u = conn.params |> normalize() |> Map.take([:uid, :content, :email, :address])

      case DB.update(u) do
        {:atomic, _} -> send_resp(conn, 200, "OK")
        _ -> send_forbidden(conn)
      end
    else
      send_forbidden(conn)
    end
  end

  get "/users/:uid" do
    case DB.lookup(uid) do
      [u] ->
        resp = u |> DB.to_map() |> Poison.encode!()
        send_resp(conn, 200, resp)

      _ ->
        send_not_found(conn)
    end
  end

  get "/count" do
    resp = DB.count() |> Integer.to_string()
    send_resp(conn, 200, resp)
  end

  get "/leader" do
    uid = conn.query_params["uid"]

    case ChainAgent.leader(uid) do
      {:ok, uid, depth} ->
        resp = %{uid: uid, depth: depth} |> Poison.encode!()
        send_resp(conn, 200, resp)

      _ ->
        send_not_found(conn)
    end
  end

  get "/chain" do
    uid = conn.query_params["uid"]

    case ChainAgent.chain(uid) do
      {:ok, uids} -> send_resp(conn, 200, Poison.encode!(uids))
      _ -> send_not_found(conn)
    end
  end

  match _, do: send_not_found(conn)

  defp send_not_found(conn) do
    send_resp(conn, 404, "Not Found")
  end

  defp send_forbidden(conn) do
    send_resp(conn, 403, "Forbidden")
  end

  defp normalize(term) when is_map(term) do
    term |> Enum.into(%{}, fn {key, value} -> {to_existing_atom(key), value} end)
  end

  defp to_existing_atom(term) do
    String.to_existing_atom(term)
  rescue
    ArgumentError -> term
  end
end
