require 'active_record/connection_adapters/abstract_adapter'
require 'data_objects'

module ActiveRecord
  class Base
    # Establishes a connection to the database that's used by all Active Record objects.
    def self.do_connection(config) # :nodoc:
      config = config.symbolize_keys
      scheme   = config[:scheme]
      host     = config[:host]
      port     = config[:port]
      username = config[:username]
      password = config[:password]
      database = config[:database]
      
      uri = config[:uri] ||"#{scheme}://#{username}:#{password}@#{host}:#{port}/#{database}"

      ConnectionAdapters::DoAdapter.new(uri, logger, config)
    end
  end

  module ConnectionAdapters
    class DoColumn < Column #:nodoc:

      # # Casts value (which is a String) to an appropriate instance.
      # def type_cast(value)
      #   return nil if value.nil?
      #   case type
      #     # cast Extlib::ByteArray to String
      #     when :text      then value.to_s
      #     else super
      #   end
      # end
      # 
      # def type_cast_code(var_name)
      #   case type
      #     when :text      then "#{var_name}.to_s"
      #     else super
      #   end
      # end

      # Convert DataObjects returned value to time
      def self.string_to_time(value)
        if value.is_a?(DateTime)
          begin
            return value.to_time
          rescue ArgumentError
            return value
          end
        end
        super
      end

    end

    class DoAdapter < AbstractAdapter

      def initialize(uri, logger, config)
        super(nil, logger)
        @uri = uri
        @config = config
        @quoted_column_names, @quoted_table_names = {}, {}
        connect
      end

      def adapter_name #:nodoc:
        'do'
      end

      def supports_migrations? #:nodoc:
        true
      end

      # QUOTING ==================================================
      def quote(value, column = nil)
        # DataObjects quoting is not compatible with ActiveRecord
        # @connection.quote_value(value)
        super
      end

      def quote_string(value)
        if @connection.quote_string(value) =~ /\A'(.*)'\Z/
          $1
        else
          raise ArgumentError, "DataObjects failed to quote string #{value.inspect}"
        end
      end

      def quote_column_name(name) #:nodoc:
        @quoted_column_names[name] ||= "\"#{name}\""
      end

      def quote_table_name(name) #:nodoc:
        @quoted_table_names[name] ||= quote_column_name(name).gsub('.', '"."')
      end


      # REFERENTIAL INTEGRITY ====================================

      # CONNECTION MANAGEMENT ====================================

      def active?
        reader = @connection.create_command(active_select_statement).execute_reader
        reader.close
        true
      rescue
        false
      end

      def reconnect!
        disconnect!
        connect
      end

      def disconnect!
        @connection.dispose rescue nil
      end

      # DATABASE STATEMENTS ======================================

      # Returns an array of arrays containing the field values.
      # Order is the same as that returned by +columns+.
      def select_rows(sql, name = nil)
        log(sql, name) do
          reader = @connection.create_command(sql).execute_reader
          rows = []
          begin
            while reader.next!
              rows << reader.values
            end
          ensure
            reader.close
          end
          rows
        end
      end

      # Executes the SQL statement in the context of this connection.
      def execute(sql, name = nil)
        log(sql, name) do
          @connection.create_command(sql).execute_non_query
        end
      end

      # TODO: waiting when DataObjects Transaction API can be used with existing connection
      # def begin_db_transaction #:nodoc:
      # end
      # 
      # def commit_db_transaction #:nodoc:
      # end
      # 
      # def rollback_db_transaction #:nodoc:
      # end
      # 
      # def create_savepoint
      # end
      # 
      # def rollback_to_savepoint
      # end
      # 
      # def release_savepoint
      # end

      # SCHEMA STATEMENTS ========================================


      protected

      def translate_exception(exception, message)
        super
      end

      # Returns an array of record hashes with the column names as keys and
      # column values as values.
      def select(sql, name = nil)
        log(sql, name) do
          reader = @connection.create_command(sql).execute_reader
          fields = reader.fields
          rows = []
          begin
            while reader.next!
              i = -1
              rows << Hash[*reader.values.map{|v| i+=1; [fields[i], typecast_value(v)]}.flatten]
            end
          ensure
            reader.close
          end
          rows
        end
      end

      # Returns the last auto-generated ID from the affected table.
      def insert_sql(sql, name = nil, pk = nil, id_value = nil, sequence_name = nil) #:nodoc:
        result = execute(sql, name)
        id_value || result.insert_id
      end

      # Executes the update statement and returns the number of rows affected.
      def update_sql(sql, name = nil) #:nodoc:
        result = execute(sql, name)
        result.to_i
      end

      private
      
      # typecast selected DataObjects value to value that will be passed to ActiveRecord
      def typecast_value(value)
        case value
        # always translate DataObjects ByteArray to String to avoid failing tests
        when Extlib::ByteArray then value.to_s
        else value
        end
      end

      def connect
        @connection = DataObjects::Connection.new(@uri)
      end

    end
  end
end
