# test 1
require 'sinatra'
require 'stripe'
# This is your real test secret API key.
Stripe.api_key = 'sk_test_M1bhxcQNJC70JtFoG7JxdMRO'	

set :static, true
set :public_folder, File.join(File.dirname(__FILE__), '.')
set :port, 4242

# Securely calculate the order amount
def calculate_order_amount(_items)
  # Replace this constant with a calculation of the order's amount
  1400
end

# An endpoint to start the payment process
post '/create-payment-intent' do
  content_type 'application/json'
  data = JSON.parse(request.body.read)

  # Create a PaymentIntent with amount and currency
  payment_intent = Stripe::PaymentIntent.create(
    amount: calculate_order_amount(data['items']),
    currency: 'usd'
  )

  {
    clientSecret: payment_intent['client_secret'],
  }.to_json
end

get '/' do
  erb :checkout
end

# AJAX endpoint when `/pay` is called from client
post '/pay' do
  data = JSON.parse(request.body.read.to_s)

  begin
    if data['payment_method_id']
      # Create the PaymentIntent
      intent = Stripe::PaymentIntent.create(
        payment_method: data['payment_method_id'],
        amount: 1099,
        currency: 'usd',
        confirmation_method: 'manual',
        confirm: true,
      )
    elsif data['payment_intent_id']
      intent = Stripe::PaymentIntent.confirm(data['payment_intent_id'])
    end
  rescue Stripe::CardError => e
    # Display error on client
    return [200, { error: e.message }.to_json]
  end

  return generate_response(intent)
end

def generate_response(intent)
  # Note that if your API version is before 2019-02-11, 'requires_action'
  # appears as 'requires_source_action'.
  if intent.status == 'requires_action' &&
      intent.next_action.type == 'use_stripe_sdk'
    # Tell the client to handle the action
    [
      200,
      {
        requires_action: true,
        payment_intent_client_secret: intent.client_secret
      }.to_json
    ]
  elsif intent.status == 'succeeded'
    # The payment didn’t need any additional actions and is completed!
    # Handle post-payment fulfillment
    [200, { success: true }.to_json]
  else
    # Invalid status
    return [500, { error: 'Invalid PaymentIntent status' }.to_json]
  end
end