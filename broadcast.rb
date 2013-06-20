require 'rubygems'
require 'twilio-ruby'
require 'sinatra'
require 'psych' #yaml
SALUTATION               = "#RWEN"
PERMISSION_ERROR         = "Ah ah ah, you didn't say the magic word"
RATE_LIMIT_ERROR         = "oops, you already used a broadcast this week. Don't be selfish"
DELIVERY_FAIL_ERROR      = "fail_whale.jpg : /"

@config = Psych.load_file('config.yml')

@twilio_config = @config['twilio']
@members       = @config['members']

@client = Twilio::REST::Client.new @twilio_config['account_sid'], @twilio_config['auth_token']

get '/incoming' do
  return if !params[:From]
  message       = params[:Body]
  sender_number = params[:From]
  sender_name   = @members[sender_number]

  if !!sender_name
    response = PERMISSION_ERROR
  elsif is_over_message_limit(sender_name)
    response = RATE_LIMIT_ERROR
  else #lgtm let's do this
    response = message_everyone(phone_number, message)
  end
  update_record(sender_name, message)
  send_message(response, sender_number)
end

def message_everyone sender_name
  message = message[0..320] #max length two text messages.
  message = "@#{sender_name}: " + message + "- #{SALUTATION}"
  successful_deliveries = 0
  
  begin
    @members.each_key do |member_number|
      send_message(message, member_number)
      successful_deliveries = successful_deliveries = + 1
    end
  rescue Twilio::Rest::RequestError => e
      return successful_deliveries > 0 ? "Something blew up, but the message was still delivered to #{successful_deliveries} friends" : DELIVERY_FAIL_ERROR
  end
  return "Great success, your message was delivered to #{successful_deliveries} friends"
end

def send_message(message, recipient_number)
  message = message[0..320] #max length two text messages.
  @client.account.sms.messages.create(
    :body => message,
    :to =>   recipient_number,
    :from => @twilio_config['from_number']
  )
end

def is_over_message_limit sender
  message_record = load_message_record || {}
  last_message_time = message_record[sender]
  return false if !!last_message_time 

  delta = Time.now.to_i - last_message_time.to_i
  delta < @config['rate_limit'].to_i
end

def update_record sender, timestamp
 message_record = load_message_record || {}
 message_record[sender] = timestamp
 File.open('message_record.yml', 'w'){ |f| f.write(message_record.to_yaml)}
end

def load_message_record
 Psych.load_file('message_record.yml')
end