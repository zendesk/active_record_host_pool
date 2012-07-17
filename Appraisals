appraise "rails2.mysql" do
  gem "activerecord", "2.3.14", :require => "active_record"
  gem "mysql"
  gem "mysql2", :git => "git://github.com/osheroff/mysql2.git", :ref => "a1ab7ba", :require => nil # silence warnings
end

appraise "rails2.mysql2" do
  gem "activerecord", "2.3.14", :require => "active_record"
  gem "mysql2", :git => "git://github.com/osheroff/mysql2.git", :ref => "a1ab7ba"
end

appraise "rails3.2.mysql2" do
  gem "activerecord", "~> 3.2.0.rc2"
  gem "mysql2", :git => "git://github.com/brianmario/mysql2.git", :ref => "d81ba9"
end
