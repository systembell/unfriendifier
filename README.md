Unfriendifier
=============

I wrote this as an excuse to play around with the Facebook API, and because I thought it would be cool to track my unfriends. It's not pretty, but it's functional, and it has a decent example of activating realtime subscriptions and responding to them in Sinatra / Koala. I also implemented a basic generator for a fake network of Facebook friends to test unfriend notifications.

It uses:

 - [Sinatra](https://github.com/sinatra/sinatra) to respond to callbacks from Facebook
 - [Koala](https://github.com/arsduo/koala) for Graph API integration
 - [Redis](http://redis.io) for caching friends lists
 - [Resque](https://github.com/defunkt/resque) as the queueing mechanism
 - [AWS SES](http://aws.amazon.com/ses) for email notifications.

