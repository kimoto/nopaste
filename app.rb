#!/bin/env ruby
# encoding: utf-8
# Author: kimoto
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'
require 'dm-timestamps'
require 'sinatra'
require 'erubis'
require 'json'
require 'redcarpet'
require 'rack/protection'
require 'sinatra/config_file'
require 'securerandom'

# Models
class Entry
  include DataMapper::Resource
  property :id, Serial
  property :digest, String, :length => 64, :unique_index => true
  property :body, Text
  timestamps :at # created_at, updated_at
  validates_presence_of :body, :message => '本文が入力されていません'

  def body_html
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    markdown.render(self.body)
  end

  before :create do |entry|
    entry.digest = SecureRandom.hex(32)
  end
end

config_file './etc/config.yaml'

# Sinatra
configure do
  enable :inline_templates
  set :erb, :escape_html => true
  set :max_entries, 10
  set :protection, true
  DataMapper.finalize
  DataMapper.setup(:default, ENV['DATABASE_URL'] || settings.dsn)
  DataMapper.auto_upgrade!
  DataMapper::Model.raise_on_save_failure = true
end

get '/' do
  @total_entries = Entry.count
  @entries = []
  erb :index
end

post '/' do
  begin
    @entry = Entry.create(:body => params[:body])
    redirect "/entry/#{@entry.digest}", 301
  rescue => ex
    content_type "application/json"
    JSON.generate({:status => {:code => 500, :text => 'Failed'}})
  end
end

post '/api/post' do
  content_type "application/json"
  begin
    @entry = Entry.create(:body => params[:body])
    JSON.generate({:status => {:code => 200, :text => 'Success!'}, :permalink => request.scheme + '://' + request.host_with_port + "/entry/#{@entry.digest}"})
  rescue
    JSON.generate({:status => {:code => 500, :text => 'Failed'}})
  end
end

get '/entry/:digest' do
  @entry = Entry.first(:digest => params[:digest])
  erb :permalink
end

get '/entry/raw/:digest' do
  content_type 'text/plain'
  @entry = Entry.first(:digest => params[:digest])
  @entry.body
end

__END__
@@ index
<html>
<body>
  <h1><a href="/">nopaste</a></h1>
  <ul>
  <% if @entry %>
  <% @entry.errors.each do |err| %>
    <li><%= err.join(", ") %></li>
  <% end %>
  <% end %>
  </ul>

  <form method="post" action="/">
    <p>markdown</p>
    <textarea name="body" style="width: 500px; height: 300px;"></textarea><br />
    <input type="submit" value="Post" />
  </form>

  <p>entries: <%= @total_entries %></p>

  <% @entries.each do |entry| %>
  <code><pre>
<%= entry.body %>
  </pre></code>
  <span><a href="/entry/<%= entry.digest %>"><%= entry.created_at %></a></span>
  <hr />
  <% end %>
</body>
</html>

@@ permalink
<html>
<body>
  <h1><a href="/">nopaste</a></h1>
  <p>
    (<a href="/entry/raw/<%= @entry.digest %>">raw</a>)
  </p>
  <code><pre>
<%== @entry.body_html %>
  </pre></code>
  </body>
</html>

