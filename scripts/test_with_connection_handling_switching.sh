#!/bin/bash

if [[ $(ruby -r active_record -e 'puts ActiveRecord.version') == 6.1.* ]]
then
  LEGACY_CONNECTION_HANDLING=true RAILS_ENV=test bundle exec rake test
  LEGACY_CONNECTION_HANDLING=false RAILS_ENV=test bundle exec rake test
else
  RAILS_ENV=test bundle exec rake test
fi
