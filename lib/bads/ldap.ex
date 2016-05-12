defmodule BADS.LDAP do
  @moduledoc """
  Helper functions for working with LDAP
  """

  @doc "Retrieve the different base DNs"
  def base_dn(type) do
    case type do
      :tdb    -> "dc=tendollarbond,dc=com"
      :groups -> "ou=groups,dc=tendollarbond,dc=com"
      :users  -> "ou=users,dc=tendollarbond,dc=com"
    end
  end

  @doc "Open an LDAP connection and return the handler"
  def connect do
    conf = Application.get_env(:bads, :ldap)
    :eldap.open([conf[:host]], [port: conf[:port]])
  end

  @doc "Create distinguished names from common names"
  def dn(user, :user) do
    "cn=#{user},#{base_dn(:users)}" |> String.to_char_list
  end
end
