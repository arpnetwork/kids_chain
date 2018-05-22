alias KidsChain.Util

require Record

defmodule KidsChain.DB do
  @moduledoc """
  A set of functions for working with user over Mnesia.
  """

  Record.defrecord(:user, [:uid, :id, :inviter, :content, :from, :to, :address])

  @timeout 5000

  # Returns a list of user fields.
  defmacrop fields(record) do
    quote do
      unquote(record) |> unquote(record) |> Keyword.keys()
    end
  end

  @doc """
  Start Mnesia and init it.
  """
  def start do
    :mnesia.create_schema([node()])
    :mnesia.start()

    :mnesia.create_table(:variable, disc_copies: [node()])

    :mnesia.create_table(
      :user,
      attributes: fields(user),
      disc_copies: [node()],
      index: [:id]
    )

    :ok = :mnesia.wait_for_tables([:variable, :user], @timeout)
  end

  @doc """
  Creates a user.
  """
  def create(%{uid: uid, inviter: inviter} = params) do
    id = id(uid)
    inviter = if inviter != "0", do: id(inviter), else: 0

    if is_nil(id) and not is_nil(inviter) do
      id = :mnesia.dirty_update_counter(:variable, :id, 1)
      u = params |> to_user() |> user(id: id, inviter: inviter)

      :mnesia.transaction(fn ->
        :mnesia.write(u)
        u
      end)
    else
      :error
    end
  end

  @doc """
  Updates the user info.
  """
  def update(%{uid: uid} = params) when is_binary(uid) do
    :mnesia.transaction(fn ->
      case :mnesia.read(:user, uid, :write) do
        [u] ->
          u = to_map(u) |> Map.merge(Util.trim(params)) |> to_user()
          :mnesia.write(u)
          u

        _ ->
          :mnesia.abort(:no_entry)
      end
    end)
  end

  @doc """
  Returns the `uid` of given `id`.
  """
  def uid(id) when is_integer(id) do
    case lookup(id) do
      [user(uid: uid)] -> uid
      _ -> nil
    end
  end

  @doc """
  Returns the `id` of given `uid`.
  """
  def id(uid) when is_binary(uid) do
    case lookup(uid) do
      [user(id: id)] -> id
      _ -> nil
    end
  end

  @doc """
  Finds the user of given `uid`.
  """
  def lookup(uid) when is_binary(uid) do
    :mnesia.dirty_read(:user, uid)
  end

  @doc """
  Finds the user of given `id`.
  """
  def lookup(id) when is_integer(id) do
    :mnesia.dirty_index_read(:user, id, :id)
  end

  @doc """
  Traverses a user table and performs operations on all records in the table.
  """
  def next(uid \\ nil) do
    uid =
      if is_nil(uid) do
        :mnesia.dirty_first(:user)
      else
        :mnesia.dirty_next(:user, uid)
      end

    if is_binary(uid) do
      lookup(uid)
    else
      []
    end
  end

  def users do
    :mnesia.dirty_select(:user, [{user(id: :"$1", inviter: :"$2", _: :_), [], [{{:"$1", :"$2"}}]}])
  end

  @doc """
  Returns the size of the users.
  """
  def count do
    :mnesia.table_info(:user, :size)
  end

  @doc """
  Converts a map to a user.
  """
  def to_user(term) when is_map(term) do
    fields(user) |> Enum.into([:user], fn key -> term[key] end) |> List.to_tuple()
  end

  @doc """
  Converts a user to a map.
  """
  def to_map(u) do
    u
    |> user()
    |> Map.new()
    |> Util.trim()
  end
end
