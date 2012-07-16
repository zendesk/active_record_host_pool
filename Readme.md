# ActiveRecord host pooling

This gem allows for one ActiveRecord connection to be used to connect to multiple databases on a server.
It accomplishes this by calling select_db() as necessary to switch databases between database calls.

## Support

For now, the only backend known to work is mysql (and not with the mysql2 library, yet).  
Postgres, from an informal reading of the docs, will never support the concept of one 
server connection sharing multiple dbs.

## Installation

    $ gem install active_record_host_pool

and make sure to require 'active\_record\_host\_pool' in some way.

## Testing
You need a local user called snoopy.

    mysql -uroot
    CREATE USER 'snoopy'@'localhost';
    GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX  ON *.* TO 'snoopy'@'localhost';
    FLUSH PRIVILEGES;

## Copyright

Copyright (c) 2011 Zendesk. See MIT-LICENSE for details.

## Authors
Ben Osheroff <ben@gimbo.net>,  
Mick Staugaard <mick@staugaard.com>
