require File.dirname(__FILE__) + '/../../../rails/activerecord/test/cases/pooled_connections_test'

class PooledConnectionsTest < ActiveRecord::TestCase

  def test_with_connection_nesting_safety
    # increased :pool to 2 as otherwise test gets stuck on Ruby 1.9.1
    if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby' && RUBY_VERSION == '1.9.1'
      pool_size = 2
    else
      pool_size = 1
    end
    ActiveRecord::Base.establish_connection(@connection.merge({:pool => pool_size, :wait_timeout => 0.1}))

    before_count = Project.count

    add_record('one')

    ActiveRecord::Base.connection.transaction do
      add_record('two')
      # Have another thread try to screw up the transaction
      Thread.new do
        ActiveRecord::Base.connection.rollback_db_transaction
        ActiveRecord::Base.connection_pool.release_connection
      end.join rescue nil
      add_record('three')
    end

    after_count = Project.count
    assert_equal 3, after_count - before_count
  end

end
