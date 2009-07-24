module ActiveRecord::ConnectionAdapters::DoAdapter::Spec
  module AdapterHelpers
    def self.current_adapters
      @current_adapters ||= []
    end

    def supported_by(*adapters, &block)
      adapters = get_adapters(*adapters)

      CONNECTION_PARAMS.only(*adapters).each do |adapter, params|
        # keep track of the current adapters
        AdapterHelpers.current_adapters << adapters

        describe("with #{adapter}") do

          before :all do
            # store these in instance vars for the shared adapter specs
            ActiveRecord::Base.establish_connection(params.merge(:adapter => adapter))
            @connection = ActiveRecord::Base.connection
          end

          self.instance_eval(&block)
        end

        AdapterHelpers.current_adapters.pop
      end
    end

    def get_adapters(*adapters)
      adapters.map! { |adapter_name| adapter_name.to_s }
      adapters = ADAPTERS if adapters.include?('all')
      ADAPTERS & adapters
    end
  end
end
