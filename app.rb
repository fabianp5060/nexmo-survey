#!/usr/bin/env ruby
#
STDOUT.sync = true

require 'sinatra'
require 'json'
require 'dm-core'
require 'dm-migrations'
require 'nexmo'
require 'logger'
require_relative 'db'

# Configure in-memory DB
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/auth.db")

Db.auto_migrate!
puts "Cleard DB on start: #{Db.destroy}"


# Update with ngrok/aws web server address
def update_webserver(app_id,web_server,app_name)
	puts "My vars: ID: #{app_id}, WS: #{web_server}, NAME: #{app_name}"
	application = $client.applications.update(
		app_id,
		{
			type: "voice",
			name: app_name,
			answer_url: "#{$web_server}/answer_survey", 
			event_url: "#{$web_server}/event_survey"
		}
	)
	puts "Updated nexmo application name:\n  #{application.name}\nwith webhooks:\n  #{application.voice.webhooks[0].endpoint}\n  #{application.voice.webhooks[1].endpoint}"
end

##ADMIN WEBSITE
get '/results' do
	@results = Db.all
	@title = $did
	erb :results
end
	

# AWS Health Check
get '/' do; 200; end

# Answer URLs
post '/event_survey' do
	request_payload = JSON.parse(request.body.read)
	puts "#{__method__} | --\n#{request_payload}\n--"
	status 200
end

get '/answer_survey' do 
	puts "#{__method__} | Make sure Things are working PARAMS | #{params}"
	db = Db.first_or_create(
		phone_number: params['from'],
		convo_id: params[:conversation_uuid],
		answers: [].to_json,
		question_num: 1
		)
	puts "#{__method__} Inspecting db entry: #{db.inspect}"
	return ncco_play_welcome
end

post '/event_ivr' do 
	request_payload = JSON.parse(request.body.read, symbolize_names: true)
	puts "#{__method__} | --\n#{request_payload}\n--"

	db = Db.get_caller_by_convo_id(request_payload[:conversation_uuid])
	puts "#{__method__}: My db result: #{db.inspect}"

	return play_next_ncco(request_payload[:dtmf],request_payload[:conversation_uuid],db)
end

def play_next_ncco(dtmf,convo_id,db)
	ncco = ""
	curr_question = db[:question_num]
	dtmf_num = dtmf.to_i
	puts "Can i read DB: #{db.inspect}"
	puts "My Question Num: #{curr_question}"

	case dtmf_num
	when "*".to_i
		ncco = ncco_play_first_question
	when 1..5
		next_question_num = db[:question_num] + 1
		record_answer(db,curr_question,dtmf_num)
		db.question_num = next_question_num
		db.save

		puts "Updated DB: #{db.inspect}"
		puts "Going to quesiton: #{next_question_num}"
		if next_question_num < $questions.length
			ncco = ncco_play_question(next_question_num)
		else
			ncco = ncco_play_thankyou
		end
	else 
		ncco = ncco_invalid_option
	end
		
	return ncco	
end

# NCCO Actions
def ncco_play_user_num(from_num)
	from_string = "#{from_num[0]},#{from_num[1..3]},#{from_num[4..6]},#{from_num[7..10]}".chars.join(" ")
	content_type :json
	return [
		{
			"action": "talk",
			"text": "Thank you, Your Number was: #{from_string}"
		}
	].to_json
end

def ncco_play_welcome
	content_type :json
	return [
		{
			"action": "talk",
			"text": "Thank you for taking our survey based on your recent visit.  Please press the star key to start the survey"			
		},
		{
			"action": "input",
			"submitOnHash": true,
			"maxDigits": 1,	
			"timeOut": 10,		
			"eventUrl": ["#{$web_server}/event_ivr"]
		}
	].to_json
end

def ncco_play_first_question
	content_type :json
	return [
		{
			"action": "talk",
			"text": $questions[1],
		},
		{
			"action": "input",
			"submitOnHash": true,
			"maxDigits": 1,
			"timeOut": 10,
			"eventUrl": ["#{$web_server}/event_ivr"]
		}
	].to_json
end

def ncco_play_question(question_num)
	puts "Playing question #{question_num}: #{$questions[question_num]}"
	content_type :json
	return [
		{
			"action": "talk",
			"text": $questions[question_num]
		},
		{
			"action": "input",
			"submitOnHash": true,
			"maxDigits": 1,
			"timeOut": 10,
			"eventUrl": ["#{$web_server}/event_ivr"]
		}
	].to_json
end

def ncco_play_thankyou
	content_type :json
	return [
		{
			"action": "talk",
			"text": "Thank you, that concludes are survey.  Please have a nice day"
		}
	].to_json
end


def ncco_invalid_option
	content_type :json
	return [
		{
			"action": "talk",
			"text": "I'm sorry, that is an invalid option.  Please try again"
		}
	].to_json
end

def record_answer(db,curr_question,answer)
	case curr_question
	when 1
		puts "made it here"
		db.question_1 = answer
	when 2
		db.question_2 = answer
	when 3
		db.question_3 = answer
	else
		"puts unable to update #{curr_question}"
	end
end

# Setup Demo Environment
key = ENV['NEXMO_API_KEY']
sec = ENV['NEXMO_API_SECRET']
app_key = ENV['NEXMO_APPLICATION_PRIVATE_KEY_PATH']

# Create Nexmo App via CLI


# Nexmo App Specific Details
app_name = ENV['SURVEY_APP_NAME']
app_id = ENV['SURVEY_APP_ID']
$did = ENV['MY_NEXMO_DID']
$web_server = ENV['SURVEY_WEB_URL'] || JSON.parse(Net::HTTP.get(URI('http://127.0.0.1:4040/api/tunnels')))['tunnels'][0]['public_url']
$questions = [
	"to lazy to offset everything by 1",
	"On a scale of 1 to 5, with 1 being the worst and 5 being the best, How satisfied where you with your most recent visit?",
	"Question 2, Again, between 1 and 5, How satisfied were you with your care giver?",
	"Question 3, How likely are you to request care again?"
]


$client = Nexmo::Client.new(
  api_key: key,
  api_secret: sec,
  application_id: app_id,
  private_key: File.read("#{app_key}")
)

update_webserver(app_id,$web_server,app_name)



