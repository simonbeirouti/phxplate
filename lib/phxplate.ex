defmodule Phxplate do
  @moduledoc """
  Phxplate keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """
  def config(keys) when is_list(keys) do
    Application.get_env(:phxplate, List.first(keys))
  end
end
