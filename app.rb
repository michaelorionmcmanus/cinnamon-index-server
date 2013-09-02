# encoding: utf-8
require 'sinatra'
require 'data_mapper'
require 'json'
require 'sinatra/cross_origin'

set :allow_origin, :any
set :allow_methods, [:get, :post, :options, :delete, :put]
set :allow_credentials, true
set :max_age, "1728000"
set :expose_headers, ['Content-Type']
set :logging, :true

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/data.db")
  class Artist
    include DataMapper::Resource
    property :id, Serial
    property :first_name, String, :required => true
    property :last_name, String, :required => true
    has n, :practices, :through => Resource
  end
  class Practice
  include DataMapper::Resource
    property :id, Serial
    property :name, String
    has n, :artists, :through => Resource
  end
DataMapper.finalize.auto_upgrade!

configure do
  enable :cross_origin
end


before do 
  content_type :json
end

options '/*' do
  response["Access-Control-Allow-Headers"] = "origin, x-requested-with, content-type"
end

get '/' do
  content_type :html

  File.read(File.join('public', 'index.html'))
end

post '/artists' do
  request.body.rewind
  @request_payload = JSON.parse request.body.read
  @artist = @request_payload["artist"]
  first_name = @artist["first_name"]
  last_name = @artist["last_name"]
  # Make the artist
  artistRecord = Artist.first_or_create(:first_name => first_name, :last_name => last_name) 

  # Loop over practices
  practices = @artist["practices"]

  if practices
    practices.each do |practice|
      practiceRecord = Practice.first_or_create(:name => practice["name"])
      artistRecord.practices << practiceRecord
    end
  end
  artistRecord.save
  status 201
  {artists: artistRecord}.to_json
end

post '/practices' do
  request.body.rewind
  @request_payload = JSON.parse request.body.read
  @practice = @request_payload["practice"]
  name = @practice["name"]
  practiceRecord = Practice.first_or_create(:name => name)
end

get '/artists' do 
  out = []
  artists = Artist.all(:fields => [:id])
  artists.each do |artist|
    attrs = artist.attributes
    practiceIds = artist.practices.all(:fields => [:id]).map(&:id)
    attrs[:practices_ids] = practiceIds
    out.push(attrs)
  end
  {artists: out}.to_json
end

delete '/artists/:id' do
  artist = Artist.get(params[:id])
  artist.artist_practices.all.destroy
  artist.destroy
end

get '/practices' do
  {practices: Practice.all}.to_json
end

delete '/practices/:id' do
  practice = Practice.get(params[:id])
  practice.artist_practices.all.destroy
  practice.destroy
end