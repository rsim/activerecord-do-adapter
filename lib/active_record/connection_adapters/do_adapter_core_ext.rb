require "bigdecimal"
unless BigDecimal.instance_methods.include?("to_d")
  BigDecimal.class_eval do
    def to_d
      self
    end
  end
end

# Add Unicode aware String#upcase and String#downcase methods when mb_chars method is called
if defined?(RUBY_ENGINE) && RUBY_ENGINE == 'ruby' && RUBY_VERSION >= '1.9'
  begin
    require "unicode_utils/upcase"
    require "unicode_utils/downcase"

    module ActiveRecord
      module ConnectionAdapters
        module DoUnicodeString
          def upcase
            UnicodeUtils.upcase(self)
          end

          def downcase
            UnicodeUtils.downcase(self)
          end
        end
      end
    end

    class String
      def mb_chars
        self.extend(ActiveRecord::ConnectionAdapters::DoUnicodeString)
        self
      end
    end

  rescue LoadError
    raise LoadError, "Please install unicode_utils gem to support Unicode aware upcase and downcase for String#mb_chars"
  end  
end
