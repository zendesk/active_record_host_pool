# ActiveRecord host pooling

This gem allows for one ActiveRecord connection to be used to connect to multiple databases on a server.
It accomplishes this by calling select_db() as necessary to switch databases between database calls.

## Support

For now, the only backend known to work is mysql.  Postgres, from an informal reading of the docs, will 
never support the concept of one server connection sharing multiple dbs.

## Installation

    $ gem install active_record_host_pooling

and make sure to require 'active\_record\_host\_pooling' in some way.


## Copyright

Copyright (c) 2011 Zendesk. See LICENSE for details.

## Authors
Ben Osheroff <ben@gimbo.net>,  
Mick Staugaard <mick@staugaard.com>
