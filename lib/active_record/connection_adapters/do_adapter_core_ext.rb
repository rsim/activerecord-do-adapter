require "bigdecimal"
unless BigDecimal.instance_methods.include?("to_d")
  BigDecimal.class_eval do
    def to_d
      self
    end
  end
end
