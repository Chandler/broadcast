require 'rubygems'
require 'twilio-ruby'
require 'sinatra'
require 'moneta'
require 'logging'

set :protection, :origin_whitelist => ['chrome-extension://fdmmgilgnpjigdojojpjoooidkmcomcm']

SALUTATION               = "#RWEN"
PERMISSION_ERROR         = "Ah ah ah, you didn't say the magic word"
RATE_LIMIT_ERROR         = "oops, you already used a broadcast this week. Don't be that person"
DELIVERY_FAIL_ERROR      = "fail_whale.jpg : /"
OPT_OUT_MESSAGES         = ["stop", "test_opt_out"]
OPT_OUT_RESPONSE         = "as you wish"

@@logger = Logging.logger['broadcast_logger']
@@logger.add_appenders(
      Logging.appenders.stdout,
          Logging.appenders.file('broadcast.log')
)

@@store         = Moneta.new(:File, :dir => 'moneta')
@@config        = Psych.load_file('config.yml')
@@twilio_config = @@config['twilio']
@@members       = @@config['members']
@@client        = Twilio::REST::Client.new @@twilio_config['account_sid'], @@twilio_config['auth_token']

set :port, 3000

#endpoint for pingdom uptime monitoring.
#get '/up' do
#  "up"
#  end
#
#  get '/' do
#   "https://github.com/Chandler/broadcast"
#   end
#
#   post '/incoming' do
#     if !params[:From]
#         status 404
#             return
#               end
#
#                 message       = params[:Body]
#                   sender_number = params[:From].to_i
#                     sender_name   = @@members[sender_number]
#                       log({:type => "incoming_message", :from_name => sender_name, :from_number => sender_number, :body => message})
#
#                         if !sender_name
#                             response = PERMISSION_ERROR
#                                 status 404
#                                   elsif is_opt_out_message(message)
#                                       #delete opting out member from the config options
#                                           @@members.delete('sender_number')
#                                               puts @@members
#                                                   puts "\n\n"
#                                                       puts @@config
#                                                           #save changes to config file
#                                                               File.open('config.yml', 'w+') { |file| file.write(Psych.dump(@@config)) }
#                                                                   response = OPT_OUT_RESPONSE
#                                                                       status 200
#                                                                         elsif is_over_message_limit(sender_name)
#                                                                             response = RATE_LIMIT_ERROR
#                                                                                 status 404
#                                                                                   else #lgtm let's do this
#                                                                                       response = message_everyone(sender_number, sender_name, message)
#                                                                                           @@store[sender_name] = Time.now.to_i
#                                                                                               status 200
#                                                                                                 end
#
#                                                                                                   send_message(response, sender_number)
#                                                                                                     response
#                                                                                                     end
#
#                                                                                                     def message_everyone sender_number, sender_name, message
#                                                                                                       # message = message[0..320] #max length two text messages.
#                                                                                                         # message = "@#{sender_name}: " + message + "  #{SALUTATION}"
#                                                                                                           # successful_deliveries = 0
#
#                                                                                                             # @@members.each_key do |member_number|
#                                                                                                               #   if member_number != sender_number
#                                                                                                                 #     if send_message(message, member_number)
#                                                                                                                   #       successful_deliveries = successful_deliveries + 1
#                                                                                                                     #     end
#                                                                                                                       #   end
#                                                                                                                         # end
#
#                                                                                                                           # if successful_deliveries == @@members.length - 1
#                                                                                                                             #   return "Great success, your message was delivered to #{successful_deliveries} friends"
#                                                                                                                               # elsif successful_deliveries > 0
#                                                                                                                                 #   return "Something blew up, but the message was still delivered to #{successful_deliveries} friends"
#                                                                                                                                   # else
#                                                                                                                                     #   return DELIVERY_FAIL_ERROR
#                                                                                                                                       # end
#                                                                                                                                       end
#
#                                                                                                                                       def send_message(message, recipient_number)
#                                                                                                                                         begin
#                                                                                                                                             if ENV['RACK_ENV'] != 'test' #test env should never send real texts
#                                                                                                                                                   @@client.account.messages.create(
#                                                                                                                                                           :body => message,
#                                                                                                                                                                   :to =>   recipient_number,
#                                                                                                                                                                           :from => @@twilio_config['from_number']
#                                                                                                                                                                                 )
#                                                                                                                                                                                     end
#                                                                                                                                                                                         log({:type => "outgoing_message_success", :to_number => recipient_number, :body => message})
#                                                                                                                                                                                             return true
#                                                                                                                                                                                               rescue Twilio::REST::RequestError => e
#                                                                                                                                                                                                   log({:exception => e.inspect})
#                                                                                                                                                                                                       log({:type => "outgoing_message_failure", :to_number => recipient_number, :body => message})
#                                                                                                                                                                                                           return false
#                                                                                                                                                                                                             end
#                                                                                                                                                                                                             end
#
#                                                                                                                                                                                                             def is_opt_out_message message
#                                                                                                                                                                                                               OPT_OUT_MESSAGES.include? message
#                                                                                                                                                                                                               end
#
#                                                                                                                                                                                                               def is_over_message_limit sender_name
#                                                                                                                                                                                                                 return false if !@@store.key? sender_name
#                                                                                                                                                                                                                   last_message_time = @@store[sender_name]
#                                                                                                                                                                                                                     delta = Time.now.to_i - last_message_time.to_i
#                                                                                                                                                                                                                       delta < @@config['rate_limit'].to_i
#                                                                                                                                                                                                                       end
#
#                                                                                                                                                                                                                       def log params
#                                                                                                                                                                                                                         params[:time] = Time.now()
#                                                                                                                                                                                                                           @@logger.info params.to_s
#                                                                                                                                                                                                                           end
#
