require 'rubygems'
require 'open-uri'
require 'simple-rss'
require 'YAML'
require 'twitter'
require 'action_view'
require 'url_shortener'

include ActionView::Helpers::TextHelper

config_file = '.config'

# Retrieve the last run state
if File.exists? config_file
  config = File.open(config_file, 'r') do|f|
    config = YAML.load(f.read)
  end  
end

# configure up the external services
  Twitter.configure do |twitter|
    twitter.consumer_key = config["twitter"]["CONSUMER_KEY"]
    twitter.consumer_secret = config["twitter"]["CONSUMER_SECRET"]
    twitter.oauth_token = config["twitter"]["OAUTH_TOKEN"]
    twitter.oauth_token_secret = config["twitter"]["OAUTH_TOKEN_SECRET"]
  end

authorise = UrlShortener::Authorize.new config["bitly"]["username"], config["bitly"]["api_key"]
bitly = UrlShortener::Client.new authorise


# Oh, and now the magic happens

config["feeds"].each do |key,value|
  puts "Checking #{key}"
  next if !value["link"]
  
  
  # default to right now just in case this is our first run. This assumes an existing blog that we don't want to spam 
  value["last_seen"] ||= Time.now
  puts "   Last Seen: #{value['last_seen']}"
  
  puts "   Feed: #{value['link']}"
  feed = SimpleRSS.parse open(value["link"])

  feed.entries.reverse.each do |entry|
    if entry.updated > value["last_seen"]
      shorten = bitly.shorten(entry.link)
      short_link =  shorten.urls
      max_length = 138 - short_link.length # 140 - link length - 2 chars for the colon & space
    
      truncated_title = truncate(entry.title, :length=>max_length)
      tweet = "#{truncated_title}: #{short_link}"
      puts "Tweeting #{tweet}"
      Twitter.update(tweet)
    end  
  end
  
  value["last_seen"] = Time.now
end

File.open(config_file, 'w') do |f|
   f << config.to_yaml
end