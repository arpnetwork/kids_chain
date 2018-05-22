alias KidsChain.DB
alias KidsChain.KChain

require DB

defmodule KidsChain.ChainAgent do
  @moduledoc """
  A simple abstraction around invite tree.
  """

  use Agent

  @type uid :: binary
  @type inviter :: uid
  @type leader :: uid
  @type depth :: non_neg_integer

  @doc """
  Starts a agent process linked to the current process.
  """
  def start_link(_opts) do
    res = Agent.start_link(fn -> nil end, name: __MODULE__)

    Agent.cast(__MODULE__, fn _ ->
      pending = :ets.new(:pending, [:bag])
      rebuild(nil, pending)
      :ets.delete(pending)
    end)

    res
  end

  @doc """
  Creates a user and then insert into invite tree.
  """
  @spec create(map) :: {:ok, depth} | :error
  def create(params) do
    Agent.get(__MODULE__, fn _ ->
      case DB.create(params) do
        {:atomic, DB.user(id: id, inviter: inviter)} -> KChain.insert(id, inviter)
        _ -> :error
      end
    end)
  end

  @doc """
  Returns the current chain leader by given `uid`.
  """
  @spec leader(uid) :: {:ok, leader, depth} | :error
  def leader(uid) do
    id = unless is_nil(uid), do: DB.id(uid), else: 0

    unless is_nil(id) do
      case KChain.leader(id) do
        {:ok, id, depth} when depth > 0 -> {:ok, DB.uid(id), depth}
        _ -> :error
      end
    else
      :error
    end
  end

  @doc """
  Returns the current chain by given `uid`.
  """
  @spec chain(uid) :: {:ok, [uid]} | :error
  def chain(uid) do
    with {:ok, uid, _} <- leader(uid),
         id = DB.id(uid),
         {:ok, ids} <- KChain.chain(id) do
      {:ok, Enum.map(ids, &DB.uid/1)}
    end
  end

  # Rebuild invite tree when restarted.
  defp rebuild(uid, pending) do
    case DB.next(uid) do
      [DB.user(uid: uid, id: id, inviter: inviter)] ->
        consume(id, inviter, pending)
        rebuild(uid, pending)

      _ ->
        :ok
    end
  end

  defp consume(id, inviter, pending) do
    case KChain.insert(id, inviter) do
      {:ok, _} ->
        :ets.lookup(pending, id)
        |> Enum.each(fn {inviter, id} ->
          consume(id, inviter, pending)
        end)

        :ets.delete(pending, id)

      :error ->
        :ets.insert(pending, {inviter, id})
    end
  end
end
