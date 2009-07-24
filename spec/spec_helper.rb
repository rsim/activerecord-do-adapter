require 'pathname'
require 'rubygems'
gem 'rspec'
require 'spec'

$:.unshift(File.dirname(__FILE__) + '/../lib')

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
$LOAD_PATH.unshift(SPEC_ROOT.parent + 'lib')

ENV['RAILS_GEM_VERSION'] ||= '2.3.2'
gem 'activerecord', '=2.3.2'

require 'activerecord'
require "active_record/connection_adapters/do_adapter"

Pathname.glob((SPEC_ROOT + 'lib/*.rb').to_s).each { |file| require file }

ENV['ADAPTERS'] ||= 'all'
ADAPTERS = []
CONNECTION_PARAMS = {
  'do_mysql' => {:host => 'localhost', :username => 'root', :password => 'admin', :database => 'ar_do_test'}
}

adapters = ENV['ADAPTERS'].split(' ').map { |adapter_name| adapter_name =~ /^do_/ ? adapter_name : "do_#{adapter_name}" }.uniq
adapters = CONNECTION_PARAMS.keys if adapters.include?('do_all')

CONNECTION_PARAMS.each do |name, options|
  next unless adapters.include?(name)
  require "active_record/connection_adapters/#{name}_adapter"
  ADAPTERS << name
end

Spec::Runner.configure do |config|
  config.extend(ActiveRecord::ConnectionAdapters::DoAdapter::Spec::AdapterHelpers)
end


