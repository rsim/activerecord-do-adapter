require "cases/helper"

class MysqlConnectionTest < ActiveRecord::TestCase
  def setup
    super
    @connection = ActiveRecord::Base.connection
  end

  # DataObjects MySQL driver turns on reconnection by default and it is not possible to switch it off

  # def test_mysql_reconnect_attribute_after_connection_with_reconnect_true
  #   run_without_connection do |orig_connection|
  #     ActiveRecord::Base.establish_connection(orig_connection.merge({:reconnect => true}))
  #     assert ActiveRecord::Base.connection.raw_connection.reconnect
  #   end
  # end
  # 
  # def test_mysql_reconnect_attribute_after_connection_with_reconnect_false
  #   run_without_connection do |orig_connection|
  #     ActiveRecord::Base.establish_connection(orig_connection.merge({:reconnect => false}))
  #     assert !ActiveRecord::Base.connection.raw_connection.reconnect
  #   end
  # end

  if RUBY_PLATFORM =~ /java/
    # DO JDBC driver will reconnect after verifying if connection is active
    def test_no_automatic_reconnection_after_timeout
      assert @connection.active?
      @connection.update('set @@wait_timeout=1')
      sleep 2
      assert !@connection.active?
    end

  else

    # DO C driver will reconnect before verifying if connection is active
    def test_automatic_reconnection_after_timeout
      assert @connection.active?
      @connection.update('set @@wait_timeout=1')
      sleep 2
      assert @connection.active?
    end

  end

  def test_successful_reconnection_after_timeout_with_manual_reconnect
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    @connection.reconnect!
    assert @connection.active?
  end

  def test_successful_reconnection_after_timeout_with_verify
    assert @connection.active?
    @connection.update('set @@wait_timeout=1')
    sleep 2
    @connection.verify!
    assert @connection.active?
  end

  private

  def run_without_connection
    original_connection = ActiveRecord::Base.remove_connection
    begin
      yield original_connection
    ensure
      ActiveRecord::Base.establish_connection(original_connection)
    end
  end
end
