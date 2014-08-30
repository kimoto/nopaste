$LOAD_PATH << File.join(File.dirname(__FILE__), "lib")
require 'sinatra'
require './app'
use Rack::Cache,
  :verbose => true
  #:metastore => 'file://./var/cache',
  #:entitystore => 'file://./var/cache'
run Sinatra::Application
