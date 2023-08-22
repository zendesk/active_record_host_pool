[![Build Status](https://github.com/zendesk/active_record_host_pool/workflows/CI/badge.svg)](https://github.com/zendesk/active_record_host_pool/actions?query=workflow%3ACI)

# ActiveRecord host pooling

This gem allows for one ActiveRecord connection to be used to connect to multiple databases on a server.
It accomplishes this by calling select_db() as necessary to switch databases between database calls.

## How Connections Are Pooled

ARHP creates separate connection pools based on the pool key.

The pool key is defined as:

`host / port / socket / username / replica`

Therefore two databases with identical host, port, socket, username, and replica status will share a connection pool.
If any part (host, port, etc.) of the pool key differ, two databases will _not_ share a connection pool.

`replica` in the pool key is a boolean indicating if the database is a replica/reader (true) or writer database (false).

Below, `test_pool_1` and `test_pool_2` have identical host, username, socket, and replica status but the port information differs.
Here the database configurations are formatted as a table to give a visual example:

|          |  test_pool_1   |  test_pool_2   |
|----------|----------------|----------------|
| host     | 127.0.0.1      | 127.0.0.1      |
| port     |                | 3306           |
| socket   |                |                |
| username | root           | root           |
| replica  | false          | false          |

The configuration items must be explicitly defined or they will be blank in the pool key.
Configurations with matching _implicit_ items but differing _explicit_ items will create separate pools.
e.g. `test_pool_1` will default to port 3306 but because it is not explicitly defined it will not share a pool with `test_pool_2`

ARHP will therefore create the following pool keys:

```
test_pool_1 => 127.0.0.1///root/false
test_pool_2 => 127.0.0.1/3306//root/false
```


## Support

For now, the only backend known to work is MySQL, with the mysql2 or activerecord-trilogy-adapter gem. When using the activerecord-trilogy-adapter ensure that the transitive dependency Trilogy is v2.5.0+.
Postgres, from an informal reading of the docs, will never support the concept of one server connection sharing multiple dbs.

## Installation

    $ gem install active_record_host_pool

and make sure to require 'active\_record\_host\_pool' in some way.

## Testing
You need a local user called 'john-doe'.

    mysql -uroot
    CREATE USER 'john-doe'@'localhost';
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX  ON *.* TO 'john-doe'@'localhost';
    FLUSH PRIVILEGES;

With mysql running locally, run

    BUNDLE_GEMFILE=gemfiles/rails5.2.gemfile bundle exec rake test

 Or

    BUNDLE_GEMFILE=gemfiles/rails5.2.gemfile ruby test/test_arhp.rb --seed 19911 --verbose

## Copyright

Copyright (c) 2011 Zendesk. See MIT-LICENSE for details.

## Authors
Ben Osheroff <ben@gimbo.net>,
Mick Staugaard <mick@staugaard.com>
