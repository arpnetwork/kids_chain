defmodule KidsChain.Util do
  @moduledoc """
  A set of util functions.
  """

  @doc """
  Returns a map where all nil value have been removed.
  """
  @spec trim(map) :: map
  def trim(term) when is_map(term) do
    term |> trim_stream() |> Enum.into(%{})
  end

  @doc """
  Creates a stream that will remove nil value on enumeration.
  """
  @spec trim_stream(map | Keyword.t()) :: Enumerable.t()
  def trim_stream(term) do
    term |> Stream.filter(&valid_kv/1)
  end

  defp valid_kv({_, value}) do
    not is_nil(value)
  end
end
