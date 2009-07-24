require File.dirname(__FILE__) + '/spec_helper.rb'

describe "Connection" do

  supported_by :all do

    it "should be connected" do
      @connection.should_not be_nil
    end

    it "should be active" do
      @connection.should be_active
    end

    it "should reconnect" do
      @connection.reconnect!
      @connection.should be_active
    end

    it "should disconnect" do
      @connection.disconnect!
      @connection.should_not be_active
      @connection.reconnect!
    end

  end

end