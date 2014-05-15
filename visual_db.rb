#!/usr/bin/env ruby

require 'sinatra'
require 'mysql'

helpers do
	include Rack::Utils
	alias_method :h, :escape_html
end

configure do
	$sql_conn = false			# The my SQL connection object
	$db_list = false			# List of available Databases
	$db_name = false			# Name of currently selected Database
	$db_tables = false			# List of Tables for currently selected Database
	$table_name = false			# Name of currently selected Table
	$db_action_response = nil 	# To propagate error/success from SQL queries
end

def sqlConnect(host, username = "root", password = "", database = "", port = 3306)
	begin
		$sql_conn = Mysql.new(host, username, password, database, port)
	rescue Mysql::Error
		$sql_conn = false
		puts Mysql::Error
	end
end

def sqlClose
	$sql_conn.close
	$sql_conn = $db_list = $db_name = $db_tables = $table_name = false
end


get '/?' do
	erb :index
end

get '/about' do
	erb :about
end

post '/connect' do
	port = Integer(params[:port]) rescue nil
	sqlConnect(params[:hostname], params[:username], params[:password], nil, port)

	redirect '/'
end

post '/disconnect' do
	sqlClose
	redirect '/'
end

get '/databases' do
	if !$sql_conn	# Force valid connection before attempting to list DB
		redirect '/'
	else
		show_dbs = $sql_conn.query "SHOW DATABASES"
		$db_list = []
		show_dbs.each do |db| $db_list += db end

		erb :databases
	end
	#$db_action_response = nil
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
			puts e.errno, e.error
			#$db_action_response = "Faliure creating #{params[:database]}" + $!.inspect
		end
	elsif params[:action] == "delete"
		begin
			$sql_conn.query "DROP DATABASE IF EXISTS #{params[:database]}"
			#$db_action_response = "Success deleting #{params[:database]}"
		rescue Mysql::Error => e
			puts e.errno, e.error
			#$db_action_response = "Failure deleting #{params[:database]}"
		end
	end
	redirect '/databases'
	#$db_action_response = nil
end

get '/tables' do
	if !$sql_conn	# Force valid connection before attempting to list DB
		redirect '/'
	elsif !$db_name
		redirect '/databases'
	else
		puts $db_name
		db_tables = $sql_conn.query "SHOW TABLES from #{$db_name}"
		$db_tables = []
		db_tables.each do |table|
			$db_tables += table
		end

		if $table_name
			$full_table = $sql_conn.query "SELECT * FROM #{$db_name}.#{$table_name}"
		end

		puts $full_table.nil?
		puts "SELECT * FROM #{$db_name}.#{$table_name}"

		erb :tables
	end
end

post '/tables' do
	$table_name = params[:select_table]

	redirect '/tables'
end

post '/table' do

end

get '/query' do
	erb :query
end