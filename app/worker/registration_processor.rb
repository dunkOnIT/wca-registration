# frozen_string_literal: true

require 'aws-sdk-dynamodb'
require 'dynamoid'
require 'httparty'

class RegistrationProcessor
  def initialize
    Dynamoid.configure do |config|
      config.region = EnvConfig.AWS_REGION
      config.namespace = nil
      if EnvConfig.CODE_ENVIRONMENT == 'development'
        config.endpoint = EnvConfig.LOCALSTACK_ENDPOINT
      else
        config.credentials = Aws::ECSCredentials.new(retries: 3)
      end
    end
  end

  def process_message(message)
    puts "Working on Message: #{message}"
    if message['step'] == 'Event Registration'
      event_registration(message['competition_id'],
                         message['user_id'],
                         message['step_details']['event_ids'],
                         message['step_details']['comment'],
                         message['step_details']['guests'])
    end
  end

  private

    def event_registration(competition_id, user_id, event_ids, comment, guests)
      # Event Registration might not be the first lane that is completed
      # TODO: When we add another lane, we need to update the registration history instead of creating it
      registration = begin
        Registration.find("#{competition_id}-#{user_id}")
      rescue Dynamoid::Errors::RecordNotFound
        initial_history = History.new({ 'changed_attributes' =>
                                          { event_ids: event_ids, comment: comment, guests: guests, status: 'pending' },
                                        'actor_user_id' => user_id,
                                        'action' => 'Worker processed' })
        RegistrationHistory.create(attendee_id: "#{competition_id}-#{user_id}", entries: [initial_history])
        Registration.new(attendee_id: "#{competition_id}-#{user_id}",
                         competition_id: competition_id,
                         user_id: user_id)
      end
      competing_lane = LaneFactory.competing_lane(event_ids: event_ids, comment: comment)
      if registration.lanes.nil?
        registration.update_attributes(lanes: [competing_lane], guests: guests)
      else
        registration.update_attributes(lanes: registration.lanes.append(competing_lane), guests: guests)
      end
      if EnvConfig.CODE_ENVIRONMENT == 'production'
        EmailApi.send_creation_email(competition_id, user_id)
      end
    end
end
