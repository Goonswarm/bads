defmodule BADS.Groups do
  @moduledoc """
  Synchronise user groups between LDAP and phpBB
  """
  use GenServer
  alias BADS.LDAP
  require Logger

  ## GenServer interface
  def start_link(args) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(config) do
    Logger.info("Starting group synchronisation process")
    interval = config[:interval] * 1000

    # Connect to LDAP
    {:ok, conn} = LDAP.connect

    # Start a timer
    :erlang.send_after(5000, self(), :update)

    state = %{
      interval: interval,
      ldap_conn: conn,
      groups: config[:groups]
    }

    {:ok, state}
  end

  def handle_info(:update, state) do
    # Restart timer. GenServer is synchronous so it won't be running twice even
    # in case of execution delays.
    :erlang.send_after(state[:interval], self(), :update)

    # Fetch current groups from phpBB
    {:ok, filters} = phpbb_get_groups

    # Do things
    groups = ldap_get_groups(state[:ldap_conn])
    update_groups(groups, filters)

    {:noreply, state}
  end

  ## Private functions for phpBB database
  @doc "Find the phpBB group ID for a group"
  def phpbb_group_id(group) do
    query = "SELECT group_id FROM phpbb_groups WHERE group_name = ?"
    case :mysql.query(:phpbb_db, query, [group]) do
      {:ok, ["group_id"], []} -> :not_found
      {:ok, ["group_id"], [[group_id]]} -> {:ok, group_id}
    end
  end

  @doc "Retrieve all phpBB groups"
  def phpbb_get_groups do
    query = "SELECT group_name FROM phpbb_groups WHERE group_type != 3"

    case :mysql.query(:phpbb_db, query, []) do
      {:ok, ["group_name"], groups} ->
        # The result list is a list of lists because of the MySQL driver. This
        # turns it into a normal string list.
        {:ok, Enum.map(groups, &(List.first &1))}
    end
  end

  @doc "Get all current members of a group in phpBB"
  def phpbb_group_members(group) do
    query = """
    SELECT LOWER(u.username)
    FROM phpbb_user_group AS ug
      JOIN phpbb_users AS u ON ug.user_id = u.user_id
      JOIN phpbb_groups AS g ON ug.group_id = g.group_id
    WHERE g.group_name = ?
    """

    {:ok, _col, users} = :mysql.query(:phpbb_db, query, [group])
    users
    |> Enum.map(fn([user]) -> user end)
  end

  @doc """
  phpBB caches user permissions seemingly forever. This query purges them and
  should let users see the new forums instantly.
  """
  def phpbb_clear_permissions_cache(uid) do
    query = """
    UPDATE phpbb_users
    SET user_permissions = ''
    WHERE user_id = ?
    """

    :ok = :mysql.query(:phpbb_db, query, [uid])
  end

  @doc "Add some users to a group"
  def phpbb_add_members(group, members) do
    {:ok, gid} = phpbb_group_id(group)
    members = ldap_user_ids(members)

    query = """
    INSERT INTO phpbb_user_group
    VALUES (?, ?, ?, ?)
    """

    Enum.map(members, fn({user, uid}) ->
      Logger.info("[phpbb] Adding #{user} to group #{group}")
      :ok = :mysql.query(:phpbb_db, query, [gid, uid, 0, 0])
      phpbb_clear_permissions_cache(uid)
    end)
  end

  @doc "Remove some users from a group"
  def phpbb_remove_members(group, members) do
    {:ok, gid} = phpbb_group_id(group)
    members = ldap_user_ids(members)
    query = """
    DELETE FROM phpbb_user_group
    WHERE group_id = ?
    AND user_id = ?
    """

    Enum.map(members, fn({user, uid}) ->
      Logger.info("[phpbb] Removing #{user} from group #{group}")
      :ok = :mysql.query(:phpbb_db, query, [gid, uid])
      phpbb_clear_permissions_cache(uid)
    end)
  end

  ## Private functions for LDAP

  @doc "Find the phpBB user ID for a user"
  def ldap_user_id(username) do
    query = """
    SELECT user_id
    FROM phpbb_users
    WHERE username = CONVERT(? USING utf8)
    COLLATE utf8_general_ci
    """
    case :mysql.query(:phpbb_db, query, [username]) do
      {:ok, ["user_id"], []} -> :not_found
      {:ok, ["user_id"], [[user_id]]} -> {:ok, username, user_id}
    end
  end

  @doc "Retrieve the IDs for several users at once, filter non-existing ones"
  def ldap_user_ids(users) do
    users
    |> Enum.map(&(ldap_user_id(&1)))
    |> Enum.filter_map(&(&1 != :not_found), fn({:ok, user, uid}) ->
      {user, uid} end)
  end

  @doc "Fetch all groups from LDAP"
  def ldap_get_groups(conn) do
    search = [base: LDAP.base_dn(:groups),
              filter: :eldap.equalityMatch('objectClass', 'groupOfNames'),
              scope: :eldap.wholeSubtree,
              attributes: ['cn', 'member']]
    {:ok, result} = :eldap.search(conn, search)

    case result do
      {:eldap_search_result, entries, _something} -> parse_ldap_groups(entries)
    end
  end

  @doc "Parses LDAP groups into a nice data structure"
  def parse_ldap_groups(entries) do
    Enum.map(entries, fn({:eldap_entry, _dn, attributes}) ->
      attributes
      |> Enum.map(&(clean_group_attribute &1))
      |> :maps.from_list
    end)
  end

  def clean_group_attribute({'cn', [value]}) do
    {:cn, List.to_string(value)}
  end
  def clean_group_attribute({'member', members}) do
    # Parse out the username from the DN
    parse_member = fn(member) ->
      member = List.to_string(member)
      <<"cn=", member :: binary>> = member
      member
      |> String.split(",")
      |> List.first
      |> String.downcase
    end
    {:member, Enum.map(members, parse_member)}
  end

  ## Private functions for logic
  @def "Filters to the groups found in phpBB and updates MariaDB"
  def update_groups(groups, filters) do
    import Enum
    groups
    |> filter(&(member?(filters, &1[:cn])))
    |> Enum.map(&(update_group &1))
  end

  @def "Updates a single group"
  def update_group(group) do
    Logger.debug("[phpbb] Checking group #{group[:cn]}")
    phpbb_members = phpbb_group_members(group[:cn])

    # Calculate list diffs
    to_add = :lists.subtract(group[:member], phpbb_members)
    to_remove = :lists.subtract(phpbb_members, group[:member])

    phpbb_add_members(group[:cn], to_add)
    phpbb_remove_members(group[:cn], to_remove)
  end
end
