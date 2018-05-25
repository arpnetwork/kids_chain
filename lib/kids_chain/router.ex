alias KidsChain.{ChainAgent, DB}
alias Plug.Conn.Status

require DB

defmodule KidsChain.Router do
  @moduledoc false

  use Plug.Router

  # /metrics endpoint for Prometheus
  plug KidsChain.PrometheusExporter
  # Collecting http metrics
  plug KidsChain.PipelineInstrumenter

  plug Plug.Parsers, parsers: [:urlencoded], pass: ["*/*"]
  plug :match
  plug :dispatch

  post "/users" do
    uid = conn.params["uid"]
    inviter = conn.params["inviter"]

    status =
      unless is_nil(uid) || is_nil(inviter) do
        keys = [:uid, :inviter, :content, :from, :to]
        u = conn.params |> normalize() |> Map.take(keys)

        if map_size(u) == length(keys) do
          case ChainAgent.create(u) do
            {:ok, _} -> :ok
            {:error, status} -> status
          end
        else
          :bad_request
        end
      else
        :bad_request
      end

    send_resp(conn, status)
  end

  patch "/users/:uid" do
    uid = conn.params["uid"]
    address = conn.params["address"]

    status =
      unless is_nil(uid) or is_nil(address) do
        case DB.update(%{uid: uid, address: address}) do
          {:atomic, _} -> :ok
          {:aborted, :not_found} -> :not_found
          _ -> :service_unavailable
        end
      else
        :bad_request
      end

    send_resp(conn, status)
  end

  get "/users/:uid" do
    case DB.lookup(uid) do
      [user] ->
        # id => uid
        fun = fn
          0 -> "0"
          id -> DB.uid(id)
        end

        resp =
          user
          |> DB.to_map()
          |> Map.update(:inviter, "0", fun)
          |> Map.delete(:id)
          |> Poison.encode!()

        send_resp(conn, :ok, resp)

      _ ->
        send_resp(conn, :not_found)
    end
  end

  get "/count" do
    resp = DB.count() |> Integer.to_string()
    send_resp(conn, :ok, resp)
  end

  get "/leader" do
    uid = conn.query_params["uid"]

    case ChainAgent.leader(uid) do
      {:ok, uid, depth} ->
        resp = %{uid: uid, depth: depth} |> Poison.encode!()
        send_resp(conn, :ok, resp)

      _ ->
        send_resp(conn, :not_found)
    end
  end

  get "/chain" do
    uid = conn.query_params["uid"]

    case ChainAgent.chain(uid) do
      {:ok, uids} -> send_resp(conn, :ok, Poison.encode!(uids))
      _ -> send_resp(conn, :not_found)
    end
  end

  match _, do: send_resp(conn, :not_found)

  defp send_resp(conn, status) when is_atom(status) do
    send_resp(conn, Status.code(status))
  end

  defp send_resp(conn, status) when is_integer(status) do
    send_resp(conn, status, Status.reason_phrase(status))
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
