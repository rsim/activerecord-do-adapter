print "Using DataObjects MySQL driver\n"
require_dependency 'models/course'
require 'logger'

# ========== for DataObjects adapter ==========
# gem "activerecord-do-adapter"
$:.unshift("../../activerecord-do-adapter/lib")
require "active_record/connection_adapters/do_mysql_adapter"

module ActiveRecord::ConnectionAdapters::MysqlAdapter
  # def execute(*args)
  #   super
  # end
end
ActiveRecord::ConnectionAdapters::DoMysqlAdapter.class_eval do
  include ActiveRecord::ConnectionAdapters::MysqlAdapter
end

DataObjects::Mysql::Connection.instance_eval do
  def pool_size
    100
  end
end

# otherwise failed with silence_warnings method missing exception
require 'active_support/core_ext/kernel/reporting'
# =============================================

ActiveRecord::Base.logger = Logger.new("debug.log")

# GRANT ALL PRIVILEGES ON activerecord_unittest.* to 'rails'@'localhost';
# GRANT ALL PRIVILEGES ON activerecord_unittest2.* to 'rails'@'localhost';

ActiveRecord::Base.configurations = {
  'arunit' => {
    :adapter  => 'do_mysql',
    :username => 'rails',
    :encoding => 'utf8',
    :database => 'activerecord_unittest',
  },
  'arunit2' => {
    :adapter  => 'do_mysql',
    :username => 'rails',
    :database => 'activerecord_unittest2'
  }
}

ActiveRecord::Base.establish_connection 'arunit'
Course.establish_connection 'arunit2'


# ========== for DataObjects adapter ==========
ActiveRecord::Base.connection.class.class_eval do
  IGNORED_SELECT_SQL = [/^PRAGMA/, /^SELECT currval/, /^SELECT CAST/, /^SELECT @@IDENTITY/, /^SELECT @@ROWCOUNT/, /^SAVEPOINT/, /^ROLLBACK TO SAVEPOINT/, /^RELEASE SAVEPOINT/, /SHOW FIELDS/]

  def select_with_query_record(sql, name = nil)
    $queries_executed ||= []
    $queries_executed << sql unless IGNORED_SELECT_SQL.any? { |r| sql =~ r }
    select_without_query_record(sql, name)
  end

  alias_method_chain :select, :query_record

end

# pluralization exceptions for ActiveRecord tests
# Extlib::Inflection.word "smarts", "smarts"
# Extlib::Inflection.word "virus", "viri"
# Extlib::Inflection.word "replies", "replies"

# Override Extlib pluralization with ActiveSupport pluralization
# works in master branch of ActiveSupport
load "active_support/core_ext/string/inflections.rb"

# =============================================

