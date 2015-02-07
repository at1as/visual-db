#!/usr/bin/env ruby

require 'sinatra'
require 'mysql'
require 'csv'

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
end

configure do
	$sql_conn   = false			  # The my SQL connection object
	$db_list    = false			  # List of available Databases
	$db_name    = false			  # Name of currently selected Database
	$db_tables  = false			  # List of Tables for currently selected Database
	$table_name = false			  # Name of currently selected Table
	$db_action_response = nil # To propagate error/success from SQL queries
end

def sql_connect(host, username = "root", password = "", database = "", port = 3306)
	begin
		$sql_conn = Mysql.new(host, username, password, database, port)
	rescue Mysql::Error
		$sql_conn = false
		puts "Error connecting to Database => #{Mysql::Error}"
	end
end

def sql_close
	$sql_conn.close
	$sql_conn = $db_list = $db_name = $db_tables = $table_name = false
end

def connection_redir(location)
  if !$sql_conn
    redirect "#{location}"
  end
end

def database_redir(location)
  if !$db_name
    redirect "#{location}"
  end
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

  #$db_action_response = nil

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
			#$db_action_response = "Success creating #{params[:database]}"
		rescue Mysql::Error => e
			puts "Error creating new database => #{e.errno} : #{e.error}"
			#$db_action_response = "Faliure creating #{params[:database]}" + $!.inspect
		end
	elsif params[:action] == "delete"
		begin
			$sql_conn.query "DROP DATABASE IF EXISTS #{params[:database]}"
			#$db_action_response = "Success deleting #{params[:database]}"
		rescue Mysql::Error => e
			puts "Error deleting existing database #{e.errno} : #{ e.error}"
			#$db_action_response = "Failure deleting #{params[:database]}"
		end
	end
	redirect '/databases'
	#$db_action_response = nil
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

  #puts $full_table.nil?
  #puts "SELECT * FROM #{$db_name}.#{$table_name}"

  erb :tables
end

post '/tables' do
	$table_name = params[:select_table]

	redirect '/tables'
end

post '/table' do
  if params[:action] == "create"
    # TODO
  elsif params[:action] == "delete"
    begin
      $sql_conn.query "DROP TABLE IF EXISTS #{$db_name}.#{params[:table]}"
    rescue Mysql::Error => e
      puts "Error dropping table => #{e.errno} : #{e.error}"
    end
    $table_name =  nil
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
    puts "Query (#{query}) resulted in error => #{e.errno} : #{e.error}"
  end

  erb :query
end

