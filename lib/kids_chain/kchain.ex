require Record

defmodule KidsChain.KChain do
  @moduledoc """
  A set of functions for working with invite tree.

  ## Example

      iex> alias KidsChain.KChain
      iex> KChain.insert(1, 0)
      {:ok, 1}
      iex> KChain.insert(2, 1)
      {:ok, 2}
      iex> KChain.insert(3, 1)
      {:ok, 2}
      iex> KChain.insert(4, 3)
      {:ok, 3}
      iex> KChain.leader()
      {:ok, 4, 3}
      iex> KChain.leader(2)
      {:ok, 2, 2}
      iex> KChain.chain()
      {:ok, [4, 3, 1]}
      iex> KChain.chain(2)
      {:ok, [2, 1]}
  """

  @type id :: integer
  @type parent :: id
  @type leader :: id
  @type depth :: integer

  use GenServer

  Record.defrecordp(:state, port: nil, pids: :queue.new(), seq: 0)

  @doc """
  Starts a KChain process linked to the current process.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc false
  def init(_opts) do
    path = System.find_executable("kchain")
    port = Port.open({:spawn_executable, path}, [:binary, {:line, 256}])
    {:ok, state(port: port)}
  end

  @doc """
  Inserts a node into invite tree.
  """
  @spec insert(id, parent) :: {:ok, depth} | :error
  def insert(id, parent) do
    args = ["i", id, parent] |> Enum.join(" ")

    case GenServer.call(__MODULE__, {:cmd, args <> "\n"}) do
      {:ok, [depth]} -> {:ok, depth}
      _ -> :error
    end
  end

  @doc """
  Returns the current chain leader by given `id`.
  """
  @spec leader(id) :: {:ok, leader, depth} | :error
  def leader(id \\ 0) do
    args = ["l", id] |> Enum.join(" ")

    case GenServer.call(__MODULE__, {:cmd, args <> "\n"}) do
      {:ok, [leader, depth]} -> {:ok, leader, depth}
      _ -> :error
    end
  end

  @doc """
  Returns the current chain by given `id`.
  """
  @spec chain(id, integer) :: {:ok, list} | :error
  def chain(id \\ 0, limit \\ 16) do
    args = ["c", id, limit] |> Enum.join(" ")

    with {:ok, ids} <- GenServer.call(__MODULE__, {:cmd, args <> "\n"}) do
      # Removes tail `0`
      {:ok, List.delete(ids, 0)}
    end
  end

  @doc false
  def handle_call({:cmd, cmd}, from, state(port: port, pids: pids) = s) do
    if Port.command(port, cmd) do
      {:noreply, state(s, pids: :queue.in(from, pids))}
    else
      {:reply, :error, s}
    end
  end

  @doc false
  def handle_info({port, {:data, {:eol, value}}}, state(port: port, pids: pids) = s) do
    res =
      case String.split(value, " ") |> Enum.map(&String.to_integer/1) do
        [0 | items] -> {:ok, items}
        _ -> :error
      end

    {{:value, pid}, pids} = :queue.out(pids)
    GenServer.reply(pid, res)

    {:noreply, state(s, pids: pids)}
  end
end
