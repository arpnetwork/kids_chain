alias KidsChain.DB
alias KidsChain.KChain

require DB
require Logger

defmodule KidsChain.ChainAgent do
  @moduledoc """
  A simple abstraction around invite tree.
  """

  use Agent

  @type uid :: binary
  @type inviter :: uid
  @type leader :: uid
  @type status :: atom
  @type depth :: non_neg_integer

  @doc """
  Starts a agent process linked to the current process.
  """
  def start_link(_opts) do
    res = Agent.start_link(fn -> nil end, name: __MODULE__)

    Agent.cast(__MODULE__, fn _ -> rebuild() end)

    res
  end

  @doc """
  Creates a user and then insert into invite tree.
  """
  @spec create(map) :: {:ok, depth} | {:error, status}
  def create(params) do
    Agent.get(__MODULE__, fn _ ->
      case DB.create(params) do
        {:atomic, DB.user(id: id, inviter: inviter)} ->
          KChain.insert(id, inviter)

        {:aborted, _reason} ->
          {:error, :service_unavailable}

        other ->
          other
      end
    end)
  end

  @doc """
  Returns the current chain leader by given `uid`.
  """
  @spec leader(uid) :: {:ok, leader, depth} | {:error, status}
  def leader(uid) do
    id = unless is_nil(uid), do: DB.id(uid), else: 0

    unless is_nil(id) do
      case KChain.leader(id) do
        {:ok, id, depth} when depth > 0 ->
          {:ok, Map.put(DB.info(id), :depth, depth)}

        {:ok, _, _} ->
          {:error, :not_found}

        _ ->
          {:error, :internal_server_error}
      end
    else
      {:error, :not_found}
    end
  end

  @doc """
  Returns the current chain by given `uid`.
  """
  @spec chain(uid) :: {:ok, [uid]} | {:error, status}
  def chain(uid) do
    with {:ok, %{uid: uid}} <- leader(uid),
         id = DB.id(uid),
         {:ok, ids} <- KChain.chain(id) do
      {:ok, Enum.map(ids, &DB.info/1)}
    else
      {:error, _} = err -> err
      _ -> {:error, :internal_server_error}
    end
  end

  # Rebuild invite tree when restarted.
  defp rebuild do
    ts = System.monotonic_time(:millisecond)

    DB.users()
    |> Enum.sort()
    |> Enum.each(fn {id, inviter} -> KChain.insert(id, inviter) end)

    ts = System.monotonic_time(:millisecond) - ts
    Logger.info("Rebuild invite tree completed. Cost #{ts}ms.")
  end
end
