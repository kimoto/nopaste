#!/bin/env ruby
# encoding: utf-8

ENV['RACK_ENV'] = 'test'

require_relative '../app'  # <-- your sinatra app
require 'rspec'
require 'rack/test'

RSpec.configure do |config|
  config.include Rack::Test::Methods
  DataMapper::setup(:default, ENV['DATABASE_URL'] || settings.dsn)
  DataMapper.finalize
  DataMapper.auto_migrate!
end

describe 'The Main App' do
  include Rack::Test::Methods
  
  def app
    Sinatra::Application
  end

  it "always true" do
    expect(true).to eq true
  end

  it "404 Not Found" do
    get '/404_not_found_path'
    expect(last_response.not_found?).to be true
  end

  it "top page" do
    get '/'
    expect(last_response.ok?).to be true
  end

  # jsonで記事登録できることの確認
  it "json api cant get" do
    get '/api/post'
    expect(last_response.ok?).to be false
  end

  # 記事の作成ができる
  it "JSON APIで記事の作成ができる" do
    post '/api/post', :body => "hello world!"
    expect(last_response.ok?).to be true
    expect(last_response.status).to be 200
    json = JSON.parse(last_response.body)
    expect(json["status"]["code"]).to be 200
    expect(json["status"]["text"]).to eq "Success!"
    expect(last_response.headers['Content-Type']).to eq("application/json")
    entry = Entry.first
    expect(Entry.count).to be 1
    expect(json["permalink"]).to eq("http://example.org/entry/" + entry.digest) # request.host = example.org
  end

  # bodyがからっぽ
  it "JSON APIでの投稿に失敗する" do
    post '/api/post', :body => ""
    expect(last_response.ok?).to be true
    expect(last_response.status).to be 200
    expect(last_response.headers['Content-Type']).to eq("application/json")
    json = JSON.parse(last_response.body)
    expect(json["status"]["code"]).to be 500
    expect(json["status"]["text"]).to eq "Failed"
    expect(Entry.count).to be 1
  end

  it "entryページが表示できる" do
    entry = Entry.first
    get "/entry/#{entry.digest}"
    expect(last_response.ok?).to be true
    expect(last_response.status).to be 200
    # viewに依存してしまうので詳細は個々ではみないことにする
  end

  it "entryページのrawページが表示できる" do
    entry = Entry.first
    get "/entry/raw/#{entry.digest}"
    expect(last_response.ok?).to be true
    expect(last_response.status).to be 200
    expect(last_response.headers['Content-Type']).to eq("text/plain;charset=utf-8")
    expect(last_response.body).to eq(entry.body)
  end

  # トップページが見れる
  it "トップページが見れる" do
    get "/"
    expect(last_response.ok?).to be true
    expect(last_response.status).to be 200
  end

  it "トップページに対して投稿出来る => bodyが空" do
    post "/", :body => ""
    expect(last_response.ok?).to be true
    expect(last_response.status).to be 200
    expect(last_response.headers['Content-Type']).to eq("application/json")
    json = JSON.parse(last_response.body)
    expect(json["status"]["code"]).to be 500
    expect(json["status"]["text"]).to eq "Failed"
  end

  it "トップページに対して投稿出来る => リダイレクト" do
    post "/", :body => "hell"
    expect(last_response.ok?).to be false
    expect(last_response.status).to be 301
    expect(last_response.headers['Content-Type']).to eq("text/html;charset=utf-8")
    entry = Entry.last
    expect(last_response.headers['Location']).to eq("http://example.org/entry/#{entry.digest}")
  end
end
