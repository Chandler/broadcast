require 'rubygems'
require 'twilio-ruby'
require 'sinatra'
require 'moneta'
require 'logging'

SALUTATION               = "#RWEN"
PERMISSION_ERROR         = "Ah ah ah, you didn't say the magic word"
RATE_LIMIT_ERROR         = "oops, you already used a broadcast this week. Don't be selfish"
DELIVERY_FAIL_ERROR      = "fail_whale.jpg : /"

@@logger        = Logging.logger(STDOUT)
@@store         = Moneta.new(:File, :dir => 'moneta')
@@config        = Psych.load_file('config.yml')
@@twilio_config = @@config['twilio']
@@members       = @@config['members']
@@client        = Twilio::REST::Client.new @@twilio_config['account_sid'], @@twilio_config['auth_token']

post '/incoming' do
  if !params[:From]
    @@logger.info "Bad request"
    return
  end

  message       = params[:Body]
  sender_number = params[:From].to_i
  sender_name   = @@members[sender_number]

  if !sender_name
    puts "hi", sender_name
    response = PERMISSION_ERROR
  elsif is_over_message_limit(sender_name)
    response = RATE_LIMIT_ERROR
  else #lgtm let's do this
    response = message_everyone(sender_number, sender_name, message)
  end

  @@store['sender'] = message
  send_message(response, sender_number)
end

def message_everyone sender_number, sender_name, message
  message = message[0..320] #max length two text messages.
  message = "@#{sender_name}: " + message + " -#{SALUTATION}"
  successful_deliveries = 0

  begin
    @@members.each_key do |member_number|
      if member_number != sender_number
        send_message(message, member_number)
        successful_deliveries = successful_deliveries + 1
      end
    end
  rescue Twilio::Rest::RequestError => e
      return successful_deliveries > 0 ? "Something blew up, but the message was still delivered to #{successful_deliveries} friends" : DELIVERY_FAIL_ERROR
  end
  return "Great success, your message was delivered to #{successful_deliveries} friends"
end

def send_message(message, recipient_number)
  @@logger.info("recipient: #{recipient_number}, message: #{message}")
  message = message[0..320] #max length two text messages.

  # @@client.account.sms.messages.create(
  #   :body => message,
  #   :to =>   recipient_number,
  #   :from => @@twilio_config['from_number']
  # )
end

def is_over_message_limit sender
  last_message_time = @@store[sender]
  return false if !!last_message_time 

  delta = Time.now.to_i - last_message_time.to_i
  delta < @@config['rate_limit'].to_i
end