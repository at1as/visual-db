#!/usr/bin/env ruby
#encoding: utf-8

require 'sinatra'
require 'mysql'
require 'csv'
require_relative 'visual_db/version'

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def sql_connect(host, username = "root", password = "", database = "", port = 3306)
    begin
      $sql_conn = Mysql.init
      $sql_conn.options(Mysql::OPT_CONNECT_TIMEOUT, 4)
      $sql_conn.real_connect(host, username, password, database, port)
      redirect "/databases"
    rescue Mysql::Error => e
      $sql_conn = false
      error_logger("Error connecting to MySQL as #{username} at #{host}:#{port}", e)
      redirect "/?error=true"
    end
  end

  def sql_close
    $sql_conn.close
    $sql_conn = $db_list = $db_name = $db_tables = $table_name = false
  end

  def connection_redir(location)
    if !$sql_conn
      error_logger("Connect to a MySQL instance before configuring databases")
      redirect "#{location}?error=true"
    end
  end

  def database_redir(location)
    if !$db_name
      error_logger("Select a Database before configuring tables")
      redirect "#{location}?error=true"
    end
  end

  def result_redirect(result, path)
    if result == "success"
      redirect "#{path}?success=true"
    else
      redirect "#{path}?error=true"
    end
  end

  def query(full_query, failure_message, update_on_success = false, update_on_fail = false)
    begin 
      data = $sql_conn.query full_query
      $db_success = $sql_conn.affected_rows
      $full_table = data if update_on_success
      return "success", data
    rescue Mysql::Error => e
      error_logger(failure_message, e)
      set_table($db_name, $table_name) if update_on_fail
      return "error", nil
    end
  end
  
  def get_table
    "#{$db_name}.#{$table_name}"
  end

  def set_table(db, table)
    begin
      $full_table = $sql_conn.query "SELECT * FROM #{db}.#{table}"
    rescue
      $full_table = $sql_conn.query "SELECT * FROM #{get_table}"
    end
  end

  def error_logger(message, exception = nil)
    $db_error = "#{message} #{'=> ' + exception.errno.to_s + ' : ' + exception.error unless exception.nil?}"
  end
end


configure do
  set :public_dir, File.expand_path('../../public', __FILE__)
  set :views, File.expand_path('../../views', __FILE__)

  Dir.glob("../*.csv").each { |csv| File.delete(csv) }
  
  $sql_conn   = false     # The my SQL connection object
  $db_list    = false     # List of available Databases
  $db_name    = false     # Name of currently selected Database
  $db_tables  = false     # List of Tables for currently selected Database
  $table_name = false     # Name of currently selected Table
  $table_cols = nil       # Table Column information
  $db_error   = nil       # To propagate error/success from SQL queries
  $db_success = nil       # SQL Rows Affected response

  NO_AUTH_PATHS = ["/", "/connect", "/disconnect", "/about"]

  set :bind, '0.0.0.0'
  set :show_exceptions, true
  set :raise_errors, true
  set :dump_errors, true
end


## Filters
before do
  connection_redir '/' unless NO_AUTH_PATHS.include? request.path_info
  $db_error   = nil unless params[:error]
  $db_success = nil unless params[:success]
  $table_cols = nil unless params[:query_action] == "showcols"
end

after do
  $table_cols = nil unless params[:query_action] == "showcols"
end


## Connection
get '/?' do
  erb :index
end

post '/connect' do
  port = Integer(params[:port]) rescue nil
  sql_connect(params[:hostname], params[:username], nil, params[:password], port)
end

post '/disconnect' do
  sql_close
  redirect '/'
end

get '/about' do
  erb :about
end


## Databases
get '/databases' do

  show_dbs = $sql_conn.query "SHOW DATABASES"
  $db_list = []
  show_dbs.each { |db| $db_list += db }
  
  erb :databases
end

post '/databases' do
  $db_name = params[:select_database]
  $db_tables, $table_name, $full_table = false, false, false
  redirect '/tables'
end

post '/database' do

  if params[:action] == "create"
    result, _ = query(  "CREATE DATABASE #{params[:database]}", 
                          "Error creating \"#{params[:database]}\"" )
  
  elsif params[:action] == "delete"
    result, _ = query(  "DROP DATABASE IF EXISTS #{params[:database]}", 
                          "Error deleting \"#{params[:database]}\"" )
    $db_name = nil if params[:database] == $db_name
  end
  
  result_redirect(result, "/databases")
end


## Selected Database - All Tables
get '/tables' do
  database_redir '/databases'  
		
  db_tables = $sql_conn.query "SHOW TABLES from #{$db_name}"
  $db_tables = []
  db_tables.each { |table| $db_tables += table }

  set_table($db_name, $table_name) if $table_name

  erb :tables
end

post '/tables' do
  $table_name = params[:select_table]

  redirect '/tables'
end


## Selected Database - Specific Table Actions
post '/table' do
  if params[:action] == "create"
    result, _ = query(  "CREATE TABLE #{$db_name}.#{params[:new_table]}",
                          "Error creating table \"#{params[:new_table]}\"" )
  
  elsif params[:action] == "delete"
    result, _ = query(  "DROP TABLE IF EXISTS #{$db_name}.#{params[:table]}",
                          "Error dropping table \"#{$db_name}.#{params[:table]}\"" )
    $table_name = nil if params[:table] == $table_name
  end

  result_redirect(result, "/tables")
end

post '/table/query' do
  if params[:query_action] == "filter"
 
    query(  "SELECT * FROM #{get_table} WHERE #{params[:query_params]}",
              "Error filtering #{$table_name} by \"#{params[:query_params]}\"",
                true, true )

  elsif params[:query_action] == "insert"

    query(  "INSERT INTO #{get_table} #{params[:set_params]}", 
              "Error inserting \"#{params[:set_params]}\" into #{$db_name}",
                true, true )
  
  elsif params[:query_action] == "delete"
    
    query(  "DELETE FROM #{get_table} WHERE #{params[:query_params]}", 
              "Error removing \"#{params[:query_params]}\" from #{$db_name}",
                true, true )

  elsif params[:query_action] == "update"
  
    query(  "UPDATE #{get_table} SET #{params[:set_params]} WHERE #{params[:query_params]}", 
              "Error setting \"#{params[:set_params]}\" to queries matching \"#{params[:query_params]}\"",
                true, true )

  elsif params[:query_action] == "alter"
  
    query(  "ALTER TABLE #{get_table} #{params[:set_params]}", 
              "Error setting \"#{params[:set_params]}\"",
                true, true )

  elsif params[:query_action] == "showcols"
    _, $table_cols = query( "SHOW COLUMNS FROM #{get_table}", "Error showing columns" )
  end

  erb :tables
end


## Manual Query
get '/query' do
  erb :query
end

post '/query' do
  result, _ = query("#{params[:query]}", "Query \"#{params[:query]}\" resulted in error")

  result_redirect(result, "/query")
end


## Download database table as CSV
post '/csv' do
  unless [$db_name, $table_name, $full_table].include? nil
    
    csv_file = "#{get_table}.csv"
    headers = [] 
    CSV.open(csv_file, "wb") do |csv|
      
      $full_table.num_fields.times do |i|
        headers << $full_table.fetch_field_direct(i).name
      end
      csv << headers

      $sql_conn.query("SELECT * FROM #{get_table}").each { |row| csv << row }
    end

    send_file csv_file, :filename => csv_file, :type => :csv
  end
end


## Default to Connection page
not_found do
  redirect '/'
end

