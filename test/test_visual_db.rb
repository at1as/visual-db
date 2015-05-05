# encoding: UTF-8
ENV['RACK_ENV'] = 'test'

require 'minitest/autorun'                                                                                                                                           
require 'rack/test'
require 'tilt/erb'
require './lib/visual_db/version'
require './lib/visual_db.rb'

class TestVisualDb < MiniTest::Test
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def setup
    @version = VisualDb::VERSION
  end


  # Version Test
  def test_version_exists
    assert_instance_of(String, @version, "Version string not present")
  end

  # No Redirect for authentication not required paths
  def test_unauthorized_index_page_no_redirect
    get '/' 
    assert last_response.ok?
    assert_equal(last_request.fullpath, "/")
  end

  def test_unauthorized_about_page_no_redirect
    get '/about'
    assert last_response.ok?
    assert_equal(last_request.fullpath, "/about")
  end

  def test_unauthorized_env_page_no_redirect
    get '/env'
    assert last_response.ok?
    assert_equal(last_request.fullpath, "/env")
  end
  
  # Redirect for Authentication Required paths
  def test_unauthorized_databases_page_redirect
    get '/databases'
    assert last_response.redirect?
    follow_redirect!
    assert_equal(last_request.fullpath, "/?error=true")
  end

  def test_unauthorized_tables_page_redirect
    get '/tables'
    assert last_response.redirect?
    follow_redirect!
    assert_equal(last_request.fullpath, "/?error=true")
  end
  
  def test_unauthorized_query_page_redirect
    get '/query'
    assert last_response.redirect?
    follow_redirect!
    assert_equal(last_request.fullpath, "/?error=true")
  end

  # Redirect for Nonexistent Pages
  def test_homepage_redirect_nonexistent_path
    get '/page_does_not_exist'
    assert last_response.redirect?
    follow_redirect!
    assert_equal(last_request.fullpath, "/?error=true")
  end

  def test_homepage_redirect_nonexistent_path_unicode
    get URI.encode('/unicode_page_does_not_exist_•ªº£™∆ƒ¬˚∂åƒ∂˚¬åßƒ∂∆å˚¬')
    assert last_response.redirect?
    follow_redirect!
    assert_equal(last_request.fullpath, "/?error=true")
  end

end

