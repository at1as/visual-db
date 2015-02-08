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
	$db_error   = nil      # To propagate error/success from SQL queries
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


after  do
  # TODO: Error notifications persist too long
  next unless request.post?
  $db_error = nil
end

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

post '/table' do
  if params[:action] == "create"
    # TODO
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
  if params[:action] == "insert"
    begin
      $sql_conn.query "INSERT INTO #{$db_name}.#{$table_name} #{params[:add_row]}"
    rescue Mysql::Error => e
      $db_error = "Error inserting #{params[:add_row]} into #{$db_name} => #{e.errno} : #{e.error}"
    end
  elsif params[:action] == "delete"
    begin
      $sql_conn.query "DELETE FROM #{$db_name}.#{$table_name} WHERE #{params[:delete_row]}"
    rescue Mysql::Error => e
      $db_error = "Error removing #{params[:add_row]} from #{$db_name} => #{e.errno} : #{e.error}"
    end
  end

  redirect '/tables'
end



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


#post 'csv' do
#  CSV.generate do |csv|
#    $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}".each { |row|
#      csv << row
#    }
#  end
#end

