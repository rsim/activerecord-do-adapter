require 'active_record/connection_adapters/do_adapter'
require 'do_mysql'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.do_mysql_connection(config) # :nodoc:
      config = config.symbolize_keys
      scheme   = 'mysql'
      host     = config[:host]
      port     = config[:port]
      username = config[:username]
      password = config[:password]
      database = config[:database]

      uri = config[:uri] ||"#{scheme}://#{username}:#{password}@#{host}:#{port}/#{database}"

      ConnectionAdapters::DoMysqlAdapter.new(uri, logger, config)
    end
  end

  module ConnectionAdapters
    class DoMysqlColumn < DoColumn #:nodoc:
    end

    class DoMysqlAdapter < DoAdapter

      QUOTED_TRUE, QUOTED_FALSE = '1'.freeze, '0'.freeze

      NATIVE_DATABASE_TYPES = {
        :primary_key => "int(11) DEFAULT NULL auto_increment PRIMARY KEY".freeze,
        :string      => { :name => "varchar", :limit => 255 },
        :text        => { :name => "text" },
        :integer     => { :name => "int", :limit => 4 },
        :float       => { :name => "float" },
        :decimal     => { :name => "decimal" },
        :datetime    => { :name => "datetime" },
        :timestamp   => { :name => "datetime" },
        :time        => { :name => "time" },
        :date        => { :name => "date" },
        :binary      => { :name => "blob" },
        :boolean     => { :name => "tinyint", :limit => 1 }
      }

      def adapter_name #:nodoc:
        'DoMySQL'
      end

      def supports_savepoints? #:nodoc:
        true
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end


      # QUOTING ==================================================

      def quote_column_name(name) #:nodoc:
        @quoted_column_names[name] ||= "`#{name}`"
      end

      def quote_table_name(name) #:nodoc:
        @quoted_table_names[name] ||= quote_column_name(name).gsub('.', '`.`')
      end

      # REFERENTIAL INTEGRITY ====================================

      def disable_referential_integrity(&block) #:nodoc:
        old = select_value("SELECT @@FOREIGN_KEY_CHECKS")

        begin
          update("SET FOREIGN_KEY_CHECKS = 0")
          yield
        ensure
          update("SET FOREIGN_KEY_CHECKS = #{old}")
        end
      end

      # CONNECTION MANAGEMENT ====================================

      def active_select_statement
        'SELECT 1'
      end

      # DATABASE STATEMENTS ======================================

      def add_limit_offset!(sql, options) #:nodoc:
        if limit = options[:limit]
          limit = sanitize_limit(limit)
          unless offset = options[:offset]
            sql << " LIMIT #{limit}"
          else
            sql << " LIMIT #{offset.to_i}, #{limit}"
          end
        end
      end

      def begin_db_transaction #:nodoc:
        execute "BEGIN"
      end

      def commit_db_transaction #:nodoc:
        execute "COMMIT"
      end

      def rollback_db_transaction #:nodoc:
        execute "ROLLBACK"
      end

      def create_savepoint
        execute("SAVEPOINT #{current_savepoint_name}")
      end
      
      def rollback_to_savepoint
        execute("ROLLBACK TO SAVEPOINT #{current_savepoint_name}")
      end
      
      def release_savepoint
        execute("RELEASE SAVEPOINT #{current_savepoint_name}")
      end

      # SCHEMA STATEMENTS ========================================


      protected

      def translate_exception(exception, message)
        super
      end

      private


    end
  end
end
