#!/bin/env ruby
# encoding: utf-8
# Author: kimoto
require 'bundler'
Bundler.require

# Models
class Entry
  include DataMapper::Resource
  property :id, Serial
  property :digest, String, :length => 64, :unique_index => true
  property :body, Text # limitation = mysql:65535
  timestamps :at # created_at, updated_at
  validates_presence_of :body, :message => '本文が入力されていません'
  validates_length_of :body, :max => 65535

  def body_html
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)
    markdown.render(self.body)
  end

  before :create do |entry|
    entry.digest = SecureRandom.hex(32) unless entry.digest
  end
end

class DataMapper::SaveFailureError
  def to_s
    self.resource.errors.inspect
  end
end

config_file './etc/config.yaml'

# Sinatra
configure do
  enable :inline_templates
  set :erb, :escape_html => true
  set :protection, true
  set :cache_time, 60
  DataMapper.finalize
  DataMapper.setup(:default, ENV['DATABASE_URL'] || settings.dsn)
  DataMapper.auto_upgrade!
  DataMapper::Model.raise_on_save_failure = true
end

def render_json(status_code, msg, ext_json={})
  content_type "application/json"
  JSON.generate({:status => {:code => status_code, :text => msg}}.merge(ext_json))
end

def render_success_json(msg, ext_json={})
  render_json(200, msg, ext_json)
end

def render_failed_json(msg, ext_json={})
  render_json(500, msg, ext_json)
end

def render_text(text)
  content_type 'text/plain'
  text
end

def entry_permalink(entry)
  return request.scheme + '://' + request.host_with_port + "/entry/#{entry.digest}"
end

get '/' do
  erb :index
end

post '/' do
  begin
    @entry = Entry.create(:body => params[:body])
    redirect entry_permalink(@entry), 301
  rescue
    render_failed_json('Failed')
  end
end

post '/api/post' do
  begin
    @entry = Entry.create(:body => params[:body])
    render_success_json('Success!', :permalink => entry_permalink(@entry))
  rescue
    render_failed_json('Failed')
  end
end

get '/entry/:digest' do
  cache_control :public, :must_revalidate, :max_age => settings.cache_time
  if @entry = Entry.first(:digest => params[:digest])
    erb :permalink
  else
    not_found
  end
end

get '/entry/raw/:digest' do
  cache_control :public, :must_revalidate, :max_age => settings.cache_time
  if @entry = Entry.first(:digest => params[:digest])
    render_text @entry.body
  else
    not_found
  end
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
</body>
</html>

@@ permalink
<html>
<head>
<link rel="stylesheet" href="http://cdnjs.cloudflare.com/ajax/libs/highlight.js/8.2/styles/github.min.css">
<script src="http://cdnjs.cloudflare.com/ajax/libs/highlight.js/8.2/highlight.min.js"></script>
<script>hljs.initHighlightingOnLoad();</script>
</head>
<body>
  <h1><a href="/">nopaste</a></h1>
  <p>
    (<a href="/entry/raw/<%= @entry.digest %>">raw</a>)
  </p>
  <pre><code>
<%= @entry.body %>
  </code></pre>
  </body>
</html>

