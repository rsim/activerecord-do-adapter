require File.dirname(__FILE__) + '/../../../rails/activerecord/test/cases/calculations_test'

class CalculationsTest < ActiveRecord::TestCase

  def test_should_sum_expression
    # DataObjects returns typecasted integer value
    assert_equal 636, Account.sum("2 * credit_limit")
  end

end
