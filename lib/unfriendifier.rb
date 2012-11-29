APP_ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..'))

require 'sinatra'
require 'koala'
require 'redis'
require 'rack/google-analytics'
require 'json'
require 'haml'
require 'date'
require 'resque'
require 'openssl'
require 'sass'
require 'eventmachine'
require File.join(File.dirname(__FILE__), 'unfriend_utils', 'unfriend_utils.rb')

API_KEY = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXX'
APP_CODE = 'XXXXXXXXXXXXXXXXXXXXXXXXXXXX'
CALLBACK_URL = 'http://example.com/fb/callback'
SITE_URL = 'http://example.com/'

class Unfriendifier < Sinatra::Application
    
  use Rack::GoogleAnalytics, :tracker => 'UA-XXXXXX-XX'
    
  include Koala
    
  set :raise_errors, true   
    set :root, APP_ROOT  
  enable :sessions

    get '/' do
        if session['access_token']
            r = Redis.new
            oauth = Koala::Facebook::OAuth.new(APP_ID, APP_CODE)
            token = oauth.get_app_access_token
            graph = Koala::Facebook::GraphAPI.new(session["access_token"])
            time = Time.now.to_i
            @user = graph.get_object("me")
            r.hmset("users:#{@user["id"]}",
                "id","#{@user["id"]}",
                "type","free",
                "name", "#{@user["name"]}",
                "first_name","#{@user["first_name"]}",
                "last_name","#{@user["last_name"]}",
                        "email", "#{@user["email"]}",
                "latest_user_token",session["access_token"],
                "latest_app_token","#{token}")
            unless r.exists("#{@user["id"]}") == true
                Resque.redis = Redis.new(:host => 'localhost', :port => '6379')
                Resque.enqueue(GetFriends, "#{@user["id"]}")
            end
            @has_baseline = r.exists("#{@user["id"]}")
            haml :index
        else
            '<a href="/login">Login</a>'
        end
    end
    
    get '/fb/callback/?' do
        meet_challenge = Koala::Facebook::RealtimeUpdates.meet_challenge(
            @params, 
            "APP_ID|XXXXXXXXXXXXXXXXXXXXXXXXXXXX")
    end

    post '/fb/callback/?' do
        content_type :json
        Resque.redis = Redis.new(:host => 'localhost', :port => '6379')
        r = Redis.new
        if request.env.include?("HTTP_X_HUB_SIGNATURE")
            x_hub_sig = request.env['HTTP_X_HUB_SIGNATURE']
            sig = x_hub_sig.split("=")[1]
            data = JSON.parse(request.body.read)
            digest  = OpenSSL::Digest::Digest.new('sha1')
            ver = OpenSSL::HMAC.hexdigest(digest, APP_CODE, request.body.read)
        if sig = ver
            accounts = data["entry"]
            accounts.each do |account|
              Resque.enqueue(DiffFriends, account["uid"])
        end
          200
        else
          403
        end
      else
        403
      end
  end

    post '/fb/drop/?' do
        oauth = Koala::Facebook::OAuth.new(APP_ID, APP_CODE)
        signed_request = oauth.parse_signed_request(params["signed_request"])
        Resque.redis = Redis.new(:host => 'localhost', :port => '6379')
        Resque.enqueue(DeleteUser, signed_request["user_id"])
    end     

    get '/login' do
        session['oauth'] = Facebook::OAuth.new(APP_ID, APP_CODE, SITE_URL + 'callback')
        redirect session['oauth'].url_for_oauth_code(:permissions => "email,offline_access,publish_stream,sms")
    end

    get '/logout' do
        session['oauth'] = nil
        session['access_token'] = nil
        redirect '/'
    end
    
    get '/callback' do
        session['access_token'] = session['oauth'].get_access_token(params[:code])
        redirect '/'
    end

    get '/guineas/?' do
        r = Redis.new
        oauth = Koala::Facebook::OAuth.new(APP_ID, APP_CODE)
        token = oauth.get_app_access_token
        graph = Koala::Facebook::GraphAPI.new(token)
            @fbtest = Koala::Facebook::TestUsers.new(:app_id => APP_ID, :app_access_token => token)
        @test_users = @fbtest.list
        haml :guinea_index
    end

    get '/guineas/create/?' do
        Resque.redis = Redis.new(:host => 'localhost', :port => '6379')
        Resque.enqueue(ReloadGuineas, "1")      
            redirect '/guineas'
    end

    get '/guineas/:uid/delete' do
        uid = params[:uid]
        oauth = Koala::Facebook::OAuth.new(APP_ID, APP_CODE)
        token = oauth.get_app_access_token
        fbtest = Koala::Facebook::TestUsers.new(:app_id => APP_ID, :app_access_token => token)
        fbtest.delete("#{uid}")
        redirect '/guineas'
    end

end
