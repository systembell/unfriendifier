require 'resque'
require 'redis'
require 'koala'

APP_ID = 'XXXXXXXXXXXXXXX'
APP_SECRET = 'XXXXXXXXXXXXXXXXXXXXXXXXX'

class ReloadGuineas
   @queue = :guinea
   def self.perform(guinea)
        oauth = Koala::Facebook::OAuth.new(APP_ID, APP_SECRET)
        token = oauth.get_app_access_token
        fbtest = Koala::Facebook::TestUsers.new(:app_id => APP_ID, :app_access_token => token)
        fbtest.delete_all
        fbtest.create_network(10, true, "offline_access,sms,publish_stream,email")
   end
end

class GetFriends
   @queue = :getFriend
   def self.perform(getFriend)
        oauth = Koala::Facebook::OAuth.new(APP_ID, APP_SECRET)
        token = oauth.get_app_access_token
        graph = Koala::Facebook::GraphAPI.new(token)
        me = graph.get_object("#{getFriend}")
        r = Redis.new
	friends = graph.get_connections("#{getFriend}", "friends")
	friends.each do |friend|
		r.sadd("#{getFriend}", friend["id"])
	end
	time = Time.now.to_i
	r.hset("users:#{getFriend}", "last_update", "#{time}")
   end
end	

class DeleteUser 
   @queue = :deleteUser
   def self.perform(deleteUser)
    	r = Redis.new
    	r.del("#{deleteUser}")
   end
end

class DiffFriends
  @queue = :fb_uid
   def self.perform(fb_uid)
        ses = AWS::SES::Base.new( :access_key_id => 'XXXXXXXXXXXXXXX',
 		:secret_access_key => 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX' )
       	oauth = Koala::Facebook::OAuth.new(APP_ID, APP_SECRET)
        token = oauth.get_app_access_token
        graph = Koala::Facebook::GraphAPI.new(token)
        rest = Koala::Facebook::RestAPI.new(token)
        me = graph.get_object("#{fb_uid}")
        r = Redis.new
        if r.exists("#{fb_uid}_latest") == true
        	latest_members = r.smembers("#{fb_uid}_latest")
        	latest_members.each do |friend|
            		r.srem("#{fb_uid}_latest", "#{friend}")
        	end
        	member_friends = graph.get_connections("#{fb_uid}", "friends")
        	member_friends.each do |member_friend|
                	r.sadd("#{fb_uid}_latest", member_friend["id"])
        	end
		else
        	member_friends = graph.get_connections("#{fb_uid}", "friends")
        	member_friends.each do |member_friend|
                	r.sadd("#{fb_uid}_latest", member_friend["id"])
        	end
		end
        	time = Time.now.to_i
        	r.hset("users:#{fb_uid}", "last_update", "#{time}")
        	friends_deleted = r.sdiff("#{fb_uid}", "#{fb_uid}_latest")
        	removed = ""
        	if friends_deleted.empty? == false
        		then
        		friends_deleted.each do |friend_del|
                	friend_del_stub = graph.get_object("#{friend_del}")
                	removed << "#{friend_del_stub["name"]}\n"
        		end
        		msg = ""
        		msg << removed
                	user_email = r.hget("users:#{fb_uid}", "email")
                	rest.rest_call("notifications.sendEmail", {
					"recipients" => "#{fb_uid}",
					"subject" => "Changes to your friends lists...",
					"text" => msg
					} )
                	r.rename("#{fb_uid}_latest", "#{fb_uid}")
        	else
                	r.rename("#{fb_uid}_latest", "#{fb_uid}")
        	end
        end
   end

