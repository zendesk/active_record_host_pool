#!/bin/bash

if [[ $(ruby -r active_record -e 'puts ActiveRecord.version') == 6.1.* ]]
then
  LEGACY_CONNECTION_HANDLING=true bundle exec rake test
  LEGACY_CONNECTION_HANDLING=false bundle exec rake test
else
  bundle exec rake test
fi
