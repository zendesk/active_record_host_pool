# frozen_string_literal: true

class AbstractPool1DbC < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: {writing: :test_pool_1_db_c}
end

# The placement of the Pool1DbC class is important so that its
# connection will not be the most recent connection established
# for test_pool_1.
class Pool1DbC < AbstractPool1DbC
end

class AbstractPool1DbA < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: {writing: :test_pool_1_db_a, reading: :test_pool_1_db_a_replica}
end

class Pool1DbA < AbstractPool1DbA
  self.table_name = "tests"
end

class Pool1DbAOther < AbstractPool1DbA
  self.table_name = "tests"
end

class AbstractPool1DbB < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: {writing: :test_pool_1_db_b}
end

class Pool1DbB < AbstractPool1DbB
  self.table_name = "tests"
end

class AbstractPool2DbD < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: {writing: :test_pool_2_db_d}
end

class Pool2DbD < AbstractPool2DbD
  self.table_name = "tests"
end

class AbstractPool2DbE < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: {writing: :test_pool_2_db_e}
end

class Pool2DbE < AbstractPool2DbE
  self.table_name = "tests"
end

class AbstractPool3DbE < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: {writing: :test_pool_3_db_e}
end

class Pool3DbE < AbstractPool3DbE
  self.table_name = "tests"
end

# Test ARHP with Rails 6.1+ horizontal sharding functionality
class AbstractShardedModel < ActiveRecord::Base
  self.abstract_class = true
  connects_to shards: {
    default: {writing: :test_pool_1_db_shard_a},
    shard_b: {writing: :test_pool_1_db_shard_b, reading: :test_pool_1_db_shard_b_replica},
    shard_c: {writing: :test_pool_1_db_shard_c, reading: :test_pool_1_db_shard_c_replica},
    shard_d: {writing: :test_pool_2_db_shard_d, reading: :test_pool_2_db_shard_d_replica}
  }
end

class ShardedModel < AbstractShardedModel
  self.table_name = "tests"
end
