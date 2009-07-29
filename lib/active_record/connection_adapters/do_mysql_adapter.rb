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
      def has_default?
        return false if type == :binary || type == :text #mysql forbids defaults on blob and text columns
        super
      end

      private

      def simplified_type(field_type)
        return :boolean if DoMysqlAdapter.emulate_booleans && field_type.downcase.index("tinyint(1)")
        return :string  if field_type =~ /enum/i
        super
      end

      def extract_limit(sql_type)
        case sql_type
        when /blob|text/i
          case sql_type
          when /tiny/i
            255
          when /medium/i
            16777215
          when /long/i
            2147483647 # mysql only allows 2^31-1, not 2^32-1, somewhat inconsistently with the tiny/medium/normal cases
          else
            super # we could return 65535 here, but we leave it undecorated by default
          end
        when /^bigint/i;    8
        when /^int/i;       4
        when /^mediumint/i; 3
        when /^smallint/i;  2
        when /^tinyint/i;   1
        else
          super
        end
      end

    end

    class DoMysqlAdapter < DoAdapter

      ##
      # :singleton-method:
      # By default, the DoMysqlAdapter will consider all columns of type <tt>tinyint(1)</tt>
      # as boolean. If you wish to disable this emulation (which was the default
      # behavior in versions 0.13.1 and earlier) you can add the following line
      # to your environment.rb file:
      #
      #   ActiveRecord::ConnectionAdapters::DoMysqlAdapter.emulate_booleans = false
      cattr_accessor :emulate_booleans
      self.emulate_booleans = true

      ADAPTER_NAME = 'DoMySQL'.freeze

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
        ADAPTER_NAME
      end

      def supports_savepoints? #:nodoc:
        true
      end

      def native_database_types #:nodoc:
        NATIVE_DATABASE_TYPES
      end

      # QUOTING ==================================================

      def quote(value, column = nil)
        if value.kind_of?(String) && column && column.type == :binary && column.class.respond_to?(:string_to_binary)
          s = column.class.string_to_binary(value).unpack("H*")[0]
          "x'#{s}'"
        else
          super
        end
      end

      def quoted_true
        QUOTED_TRUE
      end

      def quoted_false
        QUOTED_FALSE
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

      def structure_dump #:nodoc:
        # assuming that MySQL 5 is used
        sql = "SHOW FULL TABLES WHERE Table_type = 'BASE TABLE'"

        select_all(sql).inject("") do |structure, table|
          table.delete('Table_type')
          structure += select_one("SHOW CREATE TABLE #{quote_table_name(table.to_a.first.last)}")["Create Table"] + ";\n\n"
        end
      end

      def recreate_database(name, options = {}) #:nodoc:
        drop_database(name)
        create_database(name, options)
      end

      # Create a new MySQL database with optional <tt>:charset</tt> and <tt>:collation</tt>.
      # Charset defaults to utf8.
      #
      # Example:
      #   create_database 'charset_test', :charset => 'latin1', :collation => 'latin1_bin'
      #   create_database 'matt_development'
      #   create_database 'matt_development', :charset => :big5
      def create_database(name, options = {})
        if options[:collation]
          execute "CREATE DATABASE \"#{name}\" DEFAULT CHARACTER SET \"#{options[:charset] || 'utf8'}\" COLLATE \"#{options[:collation]}\""
        else
          execute "CREATE DATABASE \"#{name}\" DEFAULT CHARACTER SET \"#{options[:charset] || 'utf8'}\""
        end
      end

      def drop_database(name) #:nodoc:
        execute "DROP DATABASE IF EXISTS \"#{name}\""
      end

      def current_database
        select_value 'SELECT DATABASE() as db'
      end

      # Returns the database character set.
      def charset
        show_variable 'character_set_database'
      end

      # Returns the database collation strategy.
      def collation
        show_variable 'collation_database'
      end

      def tables(name = nil) #:nodoc:
        select_rows("SHOW TABLES", name).map {|row| row[0]}
      end

      def drop_table(table_name, options = {})
        super(table_name, options)
      end

      def indexes(table_name, name = nil)#:nodoc:
        indexes = []
        current_index = nil
        select_rows("SHOW KEYS FROM #{quote_table_name(table_name)}", name).each do |row|
          if current_index != row[2]
            next if row[2] == "PRIMARY" # skip the primary key
            current_index = row[2]
            indexes << IndexDefinition.new(row[0], row[2], row[1] == "0", [])
          end

          indexes.last.columns << row[4]
        end
        indexes
      end

      def columns(table_name, name = nil)#:nodoc:
        sql = "SHOW FIELDS FROM #{quote_table_name(table_name)}"
        columns = []
        select_rows(sql, name).each { |field| columns << DoMysqlColumn.new(field[0], field[4], field[1], field[2] == "YES") }
        columns
      end

      def create_table(table_name, options = {}) #:nodoc:
        super(table_name, options.reverse_merge(:options => "ENGINE=InnoDB"))
      end

      def rename_table(table_name, new_name)
        execute "RENAME TABLE #{quote_table_name(table_name)} TO #{quote_table_name(new_name)}"
      end

      def change_column_default(table_name, column_name, default) #:nodoc:
        column = column_for(table_name, column_name)
        change_column table_name, column_name, column.sql_type, :default => default
      end

      def change_column_null(table_name, column_name, null, default = nil)
        column = column_for(table_name, column_name)

        unless null || default.nil?
          execute("UPDATE #{quote_table_name(table_name)} SET #{quote_column_name(column_name)}=#{quote(default)} WHERE #{quote_column_name(column_name)} IS NULL")
        end

        change_column table_name, column_name, column.sql_type, :null => null
      end

      def change_column(table_name, column_name, type, options = {}) #:nodoc:
        column = column_for(table_name, column_name)

        unless options_include_default?(options)
          options[:default] = column.default
        end

        unless options.has_key?(:null)
          options[:null] = column.null
        end

        change_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(column_name)} #{type_to_sql(type, options[:limit], options[:precision], options[:scale])}"
        add_column_options!(change_column_sql, options)
        execute(change_column_sql)
      end

      def rename_column(table_name, column_name, new_column_name) #:nodoc:
        options = {}
        if column = columns(table_name).find { |c| c.name == column_name.to_s }
          options[:default] = column.default
          options[:null] = column.null
        else
          raise ActiveRecordError, "No such column: #{table_name}.#{column_name}"
        end
        current_type = select_one("SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE '#{column_name}'")["Type"]
        rename_column_sql = "ALTER TABLE #{quote_table_name(table_name)} CHANGE #{quote_column_name(column_name)} #{quote_column_name(new_column_name)} #{current_type}"
        add_column_options!(rename_column_sql, options)
        execute(rename_column_sql)
      end

      # Maps logical Rails types to MySQL-specific data types.
      def type_to_sql(type, limit = nil, precision = nil, scale = nil)
        return super unless type.to_s == 'integer'

        case limit
        when 1; 'tinyint'
        when 2; 'smallint'
        when 3; 'mediumint'
        when nil, 4, 11; 'int(11)'  # compatibility with MySQL default
        when 5..8; 'bigint'
        else raise(ActiveRecordError, "No integer type has byte size #{limit}")
        end
      end


      # SHOW VARIABLES LIKE 'name'
      def show_variable(name)
        variables = select_all("SHOW VARIABLES LIKE '#{name}'")
        variables.first['Value'] unless variables.empty?
      end

      # Returns a table's primary key and belonging sequence.
      def pk_and_sequence_for(table) #:nodoc:
        keys = []
        select_all("DESCRIBE #{quote_table_name(table)}").each do |h|
          keys << h["Field"] if h["Key"] == "PRI"
        end
        keys.length == 1 ? [keys.first, nil] : nil
      end

      def case_sensitive_equality_operator
        "= BINARY"
      end

      def limited_update_conditions(where_sql, quoted_table_name, quoted_primary_key)
        where_sql
      end


      protected

      def translate_exception(exception, message)
        case exception
        when DataObjects::SQLError
          case exception.code
          when 1062
            RecordNotUnique.new(message, exception)
          when 1452
            InvalidForeignKey.new(message, exception)
          else
            super
          end
        else
          super
        end
      end

      private

      def column_for(table_name, column_name)
        unless column = columns(table_name).find { |c| c.name == column_name.to_s }
          raise "No such column: #{table_name}.#{column_name}"
        end
        column
      end

    end
  end
end
