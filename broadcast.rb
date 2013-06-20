require 'rubygems'
require 'twilio-ruby'
require 'sinatra'

SALUTATION = "#RWEN"
PERMISSION_ERROR = "Ah ah ah, you didn't say the magic word"
RATE_LIMIT_ERROR = "oops, you already texted this week"
DELIVERY_FAIL_ERROR = "fail_whale.jpg : /"
DELIVERY_PARTIAL_SUCCESS = "Something blew up, but the message was still delivered to #{successful_deliveries} friends"
DELIVERY_SUCCESS = "Great success, your message was delivered to #{successful_deliveries} friends"

members = {
  '12089912446' => :cba,
  '12089912446' => :younglew,
  '12089912446' => :kudeki
}


get '/incoming' do
  message       = params[:Body]
  sender_number = params[:From]
  sender_name   = members[sender_number]

  if !!sender
    response = PERMISSION_ERROR
  elsif is_over_message_limit(sender)
    response = RATE_LIMIT_ERROR 
  else #lgtm let's do this
    response = message_everyone(phone_number, message)
  end

  send_message(response, sender_number)
end

def message_everyone sender
  message = message[0..320] #max length two text messages.
  message = "@#{sender}: " + message + "- #{SALUTATION}"
  successful_deliveries = 0
  
  begin
    members.each_key do |member_number|
      send_message(message, member_number)
      successful_deliveries = successful_deliveries = + 1
    end
  rescue Twilio::Rest::RequestError => e
      return successful_deliveries > 0 ? DELIVERY_PARTIAL_SUCCESS : DELIVERY_FAIL_ERROR
  end
  return DELIVERY_SUCCESS
end

def send_message(message, recipient_number)
  message = message[0..320] #max length two text messages.
  @client.account.sms.messages.create(
    :body => message,
    :to =>   recipient_number,
    :from => TWILIO_PHONE_NUMBER)
  )
end

def is_over_message_limit
  return false
end

