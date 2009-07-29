desc "Run ActiveRecord MySQLunit tests"
task :test_mysql  => :load_ar_test_env do
  Rake::Task['test_mysql_original'].invoke
end

task :load_ar_test_env do
  do_adapter_dir = pwd
  cd "../rails/activerecord"

  require 'rake/testtask'
  require File.join(Dir.pwd, 'lib', 'active_record', 'version')
  require File.expand_path(Dir.pwd) + "/test/config"

  MYSQL_DB_USER = 'rails'

  %w( mysql ).each do |adapter|
    Rake::TestTask.new("test_#{adapter}_original") do |t|
      connection_path = "#{do_adapter_dir}/test/connections/native_#{adapter}"
      adapter_short = adapter[/^[a-z]+/]
      t.libs << "test" << do_adapter_dir << connection_path
      t.test_files=Dir.glob( "test/cases/**/*_test{,_#{adapter_short}}.rb" ).sort
      t.verbose = true
    end
  end

  namespace :mysql do
    desc 'Build the MySQL test databases'
    task :build_databases do
      %x( mysqladmin --user=#{MYSQL_DB_USER} create activerecord_unittest )
      %x( mysqladmin --user=#{MYSQL_DB_USER} create activerecord_unittest2 )
    end

    desc 'Drop the MySQL test databases'
    task :drop_databases do
      %x( mysqladmin --user=#{MYSQL_DB_USER} -f drop activerecord_unittest )
      %x( mysqladmin --user=#{MYSQL_DB_USER} -f drop activerecord_unittest2 )
    end

    desc 'Rebuild the MySQL test databases'
    task :rebuild_databases => [:drop_databases, :build_databases]
  end

  task :build_mysql_databases => 'mysql:build_databases'
  task :drop_mysql_databases => 'mysql:drop_databases'
  task :rebuild_mysql_databases => 'mysql:rebuild_databases'


  namespace :postgresql do
    desc 'Build the PostgreSQL test databases'
    task :build_databases do
      %x( createdb activerecord_unittest )
      %x( createdb activerecord_unittest2 )
    end

    desc 'Drop the PostgreSQL test databases'
    task :drop_databases do
      %x( dropdb activerecord_unittest )
      %x( dropdb activerecord_unittest2 )
    end

    desc 'Rebuild the PostgreSQL test databases'
    task :rebuild_databases => [:drop_databases, :build_databases]
  end

  task :build_postgresql_databases => 'postgresql:build_databases'
  task :drop_postgresql_databases => 'postgresql:drop_databases'
  task :rebuild_postgresql_databases => 'postgresql:rebuild_databases'

end