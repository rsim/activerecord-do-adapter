require File.dirname(__FILE__) + '/../../../rails/activerecord/test/cases/query_cache_test'

class QueryCacheTest < ActiveRecord::TestCase

  def test_cache_does_not_wrap_string_results_in_arrays
    Task.cache do
      # DataObjects return typecasted integer value and not string
      assert_instance_of Fixnum, Task.connection.select_value("SELECT count(*) AS count_all FROM tasks")
    end
  end

end