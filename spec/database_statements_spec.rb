require File.dirname(__FILE__) + '/spec_helper.rb'

describe "Database statements" do

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

    it "should select rows" do
      rows = @connection.select_rows("SELECT * FROM posts")
      rows.should have_at_least(1).record
    end

    it "should select one row" do
      row = @connection.select_one("SELECT * FROM posts ORDER BY id")
      row["id"].should == 1
      row["title"].should == "Title 1"
    end

    it "should insert row" do
      insert_id = @connection.insert <<-SQL
        INSERT INTO posts (title) VALUES ('Title 2')
      SQL
      insert_id.should > 0
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should == "Title 2"
    end

    it "should update row" do
      insert_id = @connection.insert <<-SQL
        INSERT INTO posts (title) VALUES ('Title 3')
      SQL
      updated_rows = @connection.update <<-SQL
        UPDATE posts SET title = 'Title 3 updated' WHERE id = #{insert_id}
      SQL
      updated_rows.should == 1
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should == "Title 3 updated"
    end

    it "should not update non-existing row" do
      updated_rows = @connection.update <<-SQL
        UPDATE posts SET title = 'Title -1 updated' WHERE id = -1
      SQL
      updated_rows.should == 0
    end

    it "should delete row" do
      insert_id = @connection.insert <<-SQL
        INSERT INTO posts (title) VALUES ('Title 4')
      SQL
      updated_rows = @connection.update <<-SQL
        DELETE FROM posts WHERE id = #{insert_id}
      SQL
      updated_rows.should == 1
      @connection.select_value("SELECT title FROM posts WHERE id = #{insert_id}").should be_nil
    end
  end

end