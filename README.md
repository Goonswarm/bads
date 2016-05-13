Bad Account Database Synchroniser
=================================
[![Build status](https://travis-ci.org/Goonswarm/bads.svg?branch=master)](https://travis-ci.org/Goonswarm/bads)

This tool synchronises the GoonSwarm account database from LDAP to various bad
tools that keep their own account databases, currently our phpBB forums.

LDAP is an industry standard for centralising logins, group and access management
which has led to countless applications creating their own half-baked integration
with LDAP. One example of terrible software that doesn't do it properly is all
forum software currently in existence.

BADS is an Elixir application with currently a single worker process that handles
synchronisation.

The worker process sends itself timer messages at an interval specified in the
configuration file, on every tick it does the following:

## Overview - phpBB sync

1. Fetch all groups and their members from LDAP
2. Filter out groups that aren't specified in the config file
3. Fetch members for the correlating phpBB group
4. Find differences and make the necessary changes in the database

## Error handling

The MySQL driver disconnects sometimes which will mean that one request will fail,
also killing the worker process. The supervisor will restart the MySQL connection
process and the worker and things will be fine on the next run.

Every expected result is matched strictly.

## Configuration

BADS has a configuration file containing several secrets which are not currently
under separate keys. Therefore the configuration file is not in git, but I will
be fixing this soon.

The needed configuration looks like this:

```elixir
# LDAP configuration
config :bads, :ldap,
  host: 'goon-ldap',
  port: 389

# phpBB target configuration
# Note that the MySQL driver uses Erlang strings
config :bads, :phpbb,
  interval: 30,
  host: 'forum',
  database: 'phpbb3',
  user: 'phpbb',
  keepalive: true,
  password: 'TrumpForPresident2016',
  name: {:local, :phpbb_db},
  # Which groups to sync to LDAP
  groups: ["admin", "it"]
```
