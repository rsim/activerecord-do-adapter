require File.dirname(__FILE__) + '/spec_helper.rb'

describe "Transactions" do

  supported_by :all do
    before(:all) do
      @connection.execute <<-SQL
        CREATE TABLE posts (
          id int(11) NOT NULL auto_increment,
          title varchar(200),
          body text,
          PRIMARY KEY  (id)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8
      SQL
      @connection.execute <<-SQL
        INSERT INTO posts (title) VALUES ('Title 1')
      SQL
    end
    
    after(:all) do
      @connection.execute <<-SQL
        DROP TABLE posts
      SQL
    end

    it "should commit transaction" do
      @connection.begin_db_transaction
      insert_id = @connection.insert <<-SQL
        INSERT INTO posts (title) VALUES ('Title 2')
      SQL
      insert_id.should > 0
      @connection.commit_db_transaction
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should == "Title 2"
    end

    it "should rollback transaction" do
      @connection.begin_db_transaction
      insert_id = @connection.insert <<-SQL
        INSERT INTO posts (title) VALUES ('Title 2')
      SQL
      insert_id.should > 0
      @connection.rollback_db_transaction
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should be_nil
    end

    it "should commit transaction block" do
      insert_id = nil
      @connection.transaction do
        insert_id = @connection.insert <<-SQL
          INSERT INTO posts (title) VALUES ('Title 2')
        SQL
        insert_id.should > 0
      end
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should == "Title 2"
    end

    it "should rollback transaction block" do
      insert_id = nil
      @connection.transaction do
        insert_id = @connection.insert <<-SQL
          INSERT INTO posts (title) VALUES ('Title 2')
        SQL
        insert_id.should > 0
        raise ActiveRecord::Rollback
      end
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should be_nil
    end

    it "should commit nested transaction block" do
      insert_id = insert_id2 = nil
      @connection.transaction do
        (insert_id = @connection.insert(<<-SQL)).should > 0
          INSERT INTO posts (title) VALUES ('Title 2')
        SQL
        @connection.transaction(:requires_new => true) do
          (insert_id2 = @connection.insert(<<-SQL)).should > 0
            INSERT INTO posts (title) VALUES ('Title 3')
          SQL
        end
      end
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should == "Title 2"
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id2}").should == "Title 3"
    end

    it "should rollback nested inner transaction block" do
      insert_id = insert_id2 = nil
      @connection.transaction do
        (insert_id = @connection.insert(<<-SQL)).should > 0
          INSERT INTO posts (title) VALUES ('Title 2')
        SQL
        @connection.transaction(:requires_new => true) do
          (insert_id2 = @connection.insert(<<-SQL)).should > 0
            INSERT INTO posts (title) VALUES ('Title 3')
          SQL
          raise ActiveRecord::Rollback
        end
      end
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should == "Title 2"
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id2}").should be_nil
    end

    it "should rollback nested outer transaction block" do
      insert_id = insert_id2 = nil
      @connection.transaction do
        (insert_id = @connection.insert(<<-SQL)).should > 0
          INSERT INTO posts (title) VALUES ('Title 2')
        SQL
        @connection.transaction(:requires_new => true) do
          (insert_id2 = @connection.insert(<<-SQL)).should > 0
            INSERT INTO posts (title) VALUES ('Title 3')
          SQL
        end
        raise ActiveRecord::Rollback
      end
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should be_nil
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id2}").should be_nil
    end
    
  end

end