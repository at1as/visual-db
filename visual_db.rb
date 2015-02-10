#!/usr/bin/env ruby

require 'sinatra'
require 'mysql'
require 'csv'

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
end

configure do
	$sql_conn   = false			# The my SQL connection object
	$db_list    = false			# List of available Databases
	$db_name    = false			# Name of currently selected Database
	$db_tables  = false		  # List of Tables for currently selected Database
	$table_name = false		  # Name of currently selected Table
	$db_error   = nil       # To propagate error/success from SQL queries

  set :show_exceptions, true
  set :raise_errors, true
  set :dump_errors, true
end

def sql_connect(host, username = "root", password = "", database = "", port = 3306)
	begin
		$sql_conn = Mysql.new(host, username, password, database, port)
	rescue Mysql::Error
		$sql_conn = false
		$db_error = "Error connecting to Database => #{Mysql::Error}"
	end
end

def sql_close
	$sql_conn.close
	$sql_conn = $db_list = $db_name = $db_tables = $table_name = false
end

def connection_redir(location)
  if !$sql_conn
    $db_error = "Bind to MySql"
    redirect "#{location}"
  end
end

def database_redir(location)
  if !$db_name
    $db_error = "Select a Database before configuring tables"
    redirect "#{location}"
  end
end


before do
  # TODO: Error notifications persist too long
  next unless request.post?
  $db_error = nil
end


## Connection
get '/?' do
	erb :index
end

get '/about' do
	erb :about
end

post '/connect' do
	port = Integer(params[:port]) rescue nil
	sql_connect(params[:hostname], params[:username], params[:password], nil, port)

	redirect '/'
end

post '/disconnect' do
	sql_close
	redirect '/'
end


## Databases
get '/databases' do
	connection_redir '/'
 
  show_dbs = $sql_conn.query "SHOW DATABASES"
  $db_list = []
  show_dbs.each do |db| $db_list += db end
  
  erb :databases
end

post '/databases' do
	$db_name = params[:select_database]
	$db_tables, $table_name, $full_table = false, false, false
	redirect '/databases'
end

post '/database' do
	if params[:action] == "create"
		begin 
			$sql_conn.query "CREATE DATABASE #{params[:database]}"
		rescue Mysql::Error => e
			$db_error = "Error creating #{params[:database]} => #{e.errno} : #{e.error}"
		end
	elsif params[:action] == "delete"
		begin
			$sql_conn.query "DROP DATABASE IF EXISTS #{params[:database]}"
		rescue Mysql::Error => e
			$db_error = "Error deleting #{params[:database]} => #{e.errno} : #{e.error}"
    end
    if params[:database] == $db_name then $db_name = nil end
	end
	
  redirect '/databases'
end


## Selected Database - All Tables
get '/tables' do
	connection_redir '/'
  database_redir '/databases'  
		
  db_tables = $sql_conn.query "SHOW TABLES from #{$db_name}"
  $db_tables = []
  db_tables.each do |table|
    $db_tables += table
  end

  if $table_name
    $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
  end

  erb :tables
end

post '/tables' do
	$table_name = params[:select_table]

	redirect '/tables'
end


## Selected Database - Specific Table 
post '/table' do
  if params[:action] == "create"
    begin
      $sql_conn.query "CREATE TABLE #{$db_name}.#{params[:new_table]}"
    rescue Mysql::Error => e
      $db_error = "Error creating table #{params[:new_table]} => #{e.errno} : #{e.error}"
    end
  elsif params[:action] == "delete"
    begin
      $sql_conn.query "DROP TABLE IF EXISTS #{$db_name}.#{params[:table]}"
    rescue Mysql::Error => e
      $db_error = "Error dropping table #{params[:table]} from database #{$db_name} => #{e.errno} : #{e.error}"
    end
    if params[:table] == $table_name then $table_name =  nil end
  end
  
  redirect '/tables'
end

post '/table/query' do
  if params[:query_action] == "insert"
    begin
      $sql_conn.query "INSERT INTO #{$db_name}.#{$table_name} #{params[:set_params]}"
      $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
    rescue Mysql::Error => e
      $db_error = "Error inserting #{params[:set_params]} into #{$db_name} => #{e.errno} : #{e.error}"
      $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
    end
  elsif params[:query_action] == "delete"
    begin
      $sql_conn.query "DELETE FROM #{$db_name}.#{$table_name} WHERE #{params[:query_params]}"
      $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
    rescue Mysql::Error => e
      $db_error = "Error removing #{params[:query_params]} from #{$db_name} => #{e.errno} : #{e.error}"
      $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
    end
  elsif params[:query_action] == "filter"
    begin
      $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name} WHERE #{params[:query_params]}"
    rescue Mysql::Error => e
      $db_error = "Error filtering #{$table_name} by #{params[:query_params]} => #{e.errno} : #{e.error}"
      $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
    end
  elsif params[:query_action] == "update"
    begin
      $full_table = $sql_conn.query "UPDATE #{$db_name}.#{$table_name} SET #{params[:set_params]} WHERE #{params[:query_params]}"
    rescue Mysql::Error => e
      $db_error = "Error setting #{params[:set_params]} to queries matching #{params[:query_params]} => #{e.errno} : #{e.error}"
      $full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
    end
  end

  erb :tables
  #redirect '/tables'
end


## Manual Query
get '/query' do
  connection_redir '/'

  erb :query
end

post '/query' do
  begin
    query = params[:query]
    if query[-1, 1] == ";" then query << ";" end
    $sql_conn.query "#{query}"
  rescue Mysql::Error => e
    $db_error = "Query \"#{query}\" resulted in error => #{e.errno} : #{e.error}"
  end

  erb :query
end


## Download database table as CSV
post '/csv' do
  unless [$db_name, $table_name, $full_table].include? nil
    
    csv_file = "#{$db_name}.#{$table_name}.csv"
    headers = [] 
    CSV.open(csv_file, "wb") do |csv|
      
      $full_table.num_fields.times do |i|
        headers << $full_table.fetch_field_direct(i).name
      end
      csv << headers

      $sql_conn.query("SELECT * FROM #{$db_name}.#{$table_name}").each { |row| csv << row }
    end

    send_file csv_file, :filename => csv_file, :type => :csv
  end
end

