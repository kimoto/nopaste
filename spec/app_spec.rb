#!/bin/env ruby
# encoding: utf-8

describe 'The Main App', :type => :feature do
  def app
    @app = Sinatra::Application
  end

  it "常にtrue" do
    expect(true).to eq true
  end

  it "適当なパスは404になる" do
    get '/404_not_found_path'
    expect(last_response.not_found?).to be true
  end

  it "トップページはGETできる" do
    get '/'
    expect(last_response.ok?).to be true
  end

  it "JSON APIはGETできない" do
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

  it "存在しないdigestにアクセスしたら404" do
    get "/entry/not_found_digest"
    expect(last_response.ok?).to be false
    expect(last_response.status).to be 404
  end

  it "存在しないdigestにアクセスしたら404 (raw)" do
    get "/entry/raw/not_found_digest"
    expect(last_response.ok?).to be false
    expect(last_response.status).to be 404
  end

  it "entryページがキャッシュされている" do
    entry = Entry.first
    get "/entry/#{entry.digest}"
    expect(last_response.headers["Cache-Control"]).to eq("public, must-revalidate, max-age=#{@app.settings.cache_time}")
  end

  it "entry(raw)ページがキャッシュされている" do
    entry = Entry.first
    get "/entry/raw/#{entry.digest}"
    expect(last_response.headers["Cache-Control"]).to eq("public, must-revalidate, max-age=#{@app.settings.cache_time}")
  end

  it "トップページにデータ入力してボタン押して投稿できる" do
    visit '/'
    fill_in 'body', :with => 'this is my town!!'
    click_button 'Post'
    expect(page.status_code).to be 200
    entry = Entry.last
    expect(entry.body).to eq('this is my town!!')
  end
end
