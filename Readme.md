[![Build Status](https://github.com/zendesk/active_record_host_pool/workflows/CI/badge.svg)](https://github.com/zendesk/active_record_host_pool/actions?query=workflow%3ACI)

# ActiveRecord host pooling

This gem allows for one ActiveRecord connection to be used to connect to multiple databases on a server.
It accomplishes this by calling select_db() as necessary to switch databases between database calls.

## Support

For now, the only backend known to work is MySQL, with the mysql2 gem.
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
