require File.dirname(__FILE__) + '/spec_helper.rb'

describe "Schema statements" do

  supported_by :all do
    before(:all) do
      @connection.create_table :posts do |t|
        t.string :title
        t.text   :body
      end
      @connection.add_index :posts, :title
    end
    
    after(:all) do
      @connection.drop_table :posts
    end

    it "should get list of tables" do
      @connection.tables.should == ['posts']
    end

    it "should get list of primary keys and sequences" do
      @connection.pk_and_sequence_for("posts").should == ["id", nil]
    end

    it "should get list of indexes" do
      @connection.indexes("posts").first.name.should == "index_posts_on_title"
    end

    it "should get list of columns" do
      @connection.columns("posts").map{|c| c.name}.should == ["id", "title", "body"]
    end

  end

end