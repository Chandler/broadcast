require 'rubygems'
require 'twilio-ruby'
require 'sinatra'
require 'time_difference'

config = YAML.load_file('config.yml').symbolize_keys
twilio_config = config[:twilio]
members       = config[:members]
constants     = config[:constants]

@client = Twilio::REST::Client.new twilio_config[:account_sid], twilio_config[:auth_token]

get '/incoming' do
  message       = params[:Body]
  sender_number = params[:From]
  sender_name   = members[sender_number]

  if !!sender
    response = constants[:PERMISSION_ERROR]
  elsif is_over_message_limit(sender)
    response = constants[:RATE_LIMIT_ERROR]
  else #lgtm let's do this
    response = message_everyone(phone_number, message)
  end
  update_record(sender_name, message)
  send_message(response, sender_number)
end

def message_everyone sender
  message = message[0..320] #max length two text messages.
  message = "@#{sender}: " + message + "- #{constants[:SALUTATION]}"
  successful_deliveries = 0
  
  begin
    members.each_key do |member_number|
      send_message(message, member_number)
      successful_deliveries = successful_deliveries = + 1
    end
  rescue Twilio::Rest::RequestError => e
      return successful_deliveries > 0 ? constants[:DELIVERY_PARTIAL_SUCCESS] : constants[:DELIVERY_FAIL_ERROR]
  end
  constants[:DELIVERY_SUCCESS]
end

def send_message(message, recipient_number)
  message = message[0..320] #max length two text messages.
  @client.account.sms.messages.create(
    :body => message,
    :to =>   recipient_number,
    :from => twilio_config[:from_number])
  )
end

def is_over_message_limit sender
  message_record = load_message_record || {}
  last_message_time = message_record[sender]
  if !!last_message_time return false

  delta = Time.now.to_i - last_message_time.to_i
  delta < config[:rate_limit].to_i
end

def update_record sender, timestamp
 message_record = load_message_record || {}
 message_record[sender] = timestamp
 File.open('message_record.yml', 'w'){ |f| f.write(message_record.to_yaml)}
end

def load_message_record
 YAML.load_file('message_record.yml').symbolize_keys
end