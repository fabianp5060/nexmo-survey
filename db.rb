class Db
	include DataMapper::Resource
	property :id, Serial
	property :question_num, Integer	
	property :question_1, String
	property :question_2, String
	property :question_3, String
	property :convo_id, String
	property :answers, String
	property :phone_number, String

	def self.get_caller_by_convo_id(convo_id)
		puts "#{__method__}: looing for: #{convo_id}"
		first(convo_id: convo_id)
	end

	def self.update_question_num(question_num)
		update(question_num: question_num)
	end
end