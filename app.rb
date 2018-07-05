#!/bin/env ruby
# encoding: utf-8
# Author: kimoto
require 'bundler'
Bundler.require

require 'net/http'

# 記事を表すクラス
class Entry
  include DataMapper::Resource
  property :id, Serial
  property :digest, String, :length => 64, :unique_index => true
  property :body, Text # limitation = mysql:65535
  timestamps :at # created_at, updated_at
  validates_presence_of :body, :message => '本文が入力されていません'
  validates_length_of :body, :max => 65535

  before :create do |entry|
    entry.digest = SecureRandom.hex(32) unless entry.digest
  end
end

class DataMapper::SaveFailureError
  # 元の例外クラスのエラー文字列がわかりにくいので変更している
  def to_s
    self.resource.errors.inspect
  end
end

config_file './etc/config.yml'

# Sinatra
configure do
  recaptcha_token = ENV['RECAPTCHA_TOKEN'] || settings.recaptcha_token rescue nil

  enable :inline_templates
  set :erb, :escape_html => true
  set :protection, true
  set :cache_time, 60
  set :recaptcha_token, recaptcha_token
  DataMapper.finalize
  DataMapper.setup(:default, ENV['DATABASE_URL'] || settings.dsn)
  DataMapper.auto_upgrade!
  DataMapper.logger.set_log STDERR, :debug, "", true
  DataMapper::Model.raise_on_save_failure = true
end

def render_json(status_code, msg, ext_json={})
  content_type "application/json"
  JSON.generate({:status => {:code => status_code, :text => msg}}.merge(ext_json))
end

def render_text(text)
  content_type 'text/plain'
  text
end

# 記事のpermalinkのURL文字列を返す
# @param [Entry] entry 記事インスタンス
# @return [String] URL文字列
def entry_permalink(entry)
  return request.scheme + '://' + request.host_with_port + "/entry/#{entry.digest}"
end

get '/' do
  erb :index
end

post '/' do
  begin
    unless validate_recaptcha( params["g-recaptcha-response"] )
      raise "You arent human!"
    end

    @entry = Entry.create(:body => params[:body])
    redirect entry_permalink(@entry), 301
  rescue => ex
    render_json(500, "Failed: #{ex.message}")
  end
end

def validate_recaptcha(code)
  resp = Net::HTTP.post_form(
    URI("https://www.google.com/recaptcha/api/siteverify"),
    :secret => '6Ldn19cSAAAAAC_BL3p8LILXiCJGO8UwPV-ePdjo',
    :response => code, :remote_ip => request.ip)
  json = JSON.parse(resp.body)
  return json["success"]
end

post '/api/post' do
  begin
    @entry = Entry.create(:body => params[:body])
    render_json(200, 'Success!', :permalink => entry_permalink(@entry))
  rescue
    render_json(500, 'Failed')
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
<head>
  <script src='https://www.google.com/recaptcha/api.js'></script>
</head>
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
    <textarea name="body" style="width: 500px; height: 300px;"></textarea><br />
    <div class="g-recaptcha" data-sitekey="<%= settings.recaptcha_token %>"></div>
    <input type="submit" style="font-size: 200%; height: 50px; width: 200px;" value="Post" />
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

