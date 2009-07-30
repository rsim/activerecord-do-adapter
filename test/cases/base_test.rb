require File.dirname(__FILE__) + '/../../../rails/activerecord/test/cases/base_test'

class BasicsTest < ActiveRecord::TestCase

  if current_adapter?(:MysqlAdapter)
    def test_read_attributes_before_type_cast_on_boolean
      bool = Booleantest.create({ "value" => false })
      # DataObjects return typecasted boolean value and not string
      assert_equal false, bool.reload.attributes_before_type_cast["value"]
    end
  end

  def test_read_attributes_before_type_cast_on_datetime
    developer = Developer.find(:first)
    # DataObjects return typecasted integer value and not string
    assert_equal developer.created_at.to_s(:db) , developer.attributes_before_type_cast["created_at"].to_s(:db)
  end

  def test_assert_queries
    # with DataObjects JDBC driver you cannot do exec with SELECT statement
    query = lambda { ActiveRecord::Base.connection.select_value 'select count(*) from developers' }
    assert_queries(2) { 2.times { query.call } }
    assert_queries 1, &query
    assert_no_queries { assert true }
  end

end
