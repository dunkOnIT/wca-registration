# frozen_string_literal: true

require 'time'

class Registration
  include Dynamoid::Document

  # We autoscale dynamodb
  table name: EnvConfig.DYNAMO_REGISTRATIONS_TABLE, capacity_mode: nil, key: :attendee_id

  REGISTRATION_STATES = %w[pending waiting_list accepted cancelled].freeze
  ADMIN_ONLY_STATES = %w[pending waiting_list accepted].freeze # Only admins are allowed to change registration state to one of these states

  # Pre-validations
  before_validation :set_competing_status

  # Validations
  validate :competing_status_consistency

  def self.accepted_competitors(competition_id)
    where(competition_id: competition_id, competing_status: 'accepted').count
  end

  def self.get_registrations_by_status(competition_id, status)
    result = Rails.cache.fetch("#{competition_id}-#{status}_registrations", expires_in: 60.minutes) do
      Registration.where(competition_id: competition_id, competing_status: status).to_a
    end
    unless result.is_a? Array
      return []
    end
    result
  end

  def self.accepted_competitors_count(competition_id)
    Rails.cache.fetch("#{competition_id}-accepted-count", expires_in: 60.minutes, raw: true) do
      self.accepted_competitors(competition_id)
    end
  end

  def self.decrement_competitors_count(competition_id)
    RedisHelper.decrement_or_initialize("#{competition_id}-accepted-count") do
      self.accepted_competitors(competition_id)
    end
  end

  def self.increment_competitors_count(competition_id)
    RedisHelper.increment_or_initialize("#{competition_id}-accepted-count") do
      self.accepted_competitors(competition_id)
    end
  end

  def competing_lane
    lanes&.find { |x| x.lane_name == 'competing' }
  end

  def payment_lane
    lanes&.find { |x| x.lane_name == 'payment' }
  end

  # Returns all event ids irrespective of registration status
  def event_ids
    competing_lane&.lane_details&.[]('event_details')&.pluck('event_id')
  end

  def registered_event_ids
    event_ids = []

    competing_lane.lane_details['event_details'].each do |event|
      if event['event_registration_state'] != 'cancelled'
        event_ids << event['event_id']
      end
    end
    event_ids
  end

  def event_details
    competing_lane&.lane_details&.[]('event_details')
  end

  def competing_waiting_list_position
    competing_lane&.lane_details&.[]('waiting_list_position')
  end

  def competing_comment
    competing_lane&.lane_details&.[]('comment')
  end

  def admin_comment
    competing_lane&.lane_details&.[]('admin_comment')
  end

  def payment_ticket
    payment_lane&.lane_details&.[]('payment_id')
  end

  def payment_status
    payment_lane&.lane_state
  end

  def payment_date
    payment_lane&.lane_details&.[]('last_updated')
  end

  def payment_history
    payment_lane&.lane_details&.[]('payment_history')
  end

  def update_competing_waiting_list_position(new_position)
    updated_lanes = lanes.map do |lane|
      if lane.lane_name == 'competing'
        lane.lane_details['waiting_list_position'] = new_position
      end
      lane
    end
    update_attributes!(lanes: updated_lanes, competing_status: competing_lane.lane_state, guests: guests)
  end

  def update_competing_lane!(update_params)
    has_waiting_list_changed = waiting_list_changed?(update_params)

    updated_lanes = lanes.map do |lane|
      if lane.lane_name == 'competing'

        # Update status for lane and events
        if has_waiting_list_changed
          update_waiting_list(lane, update_params)
        end

        if update_params[:status].present?
          lane.lane_state = update_params[:status]

          lane.lane_details['event_details'].each do |event|
            # NOTE: Currently event_registration_state is not used - when per-event registrations are added, we need to add validation logic to support cases like
            # limited registrations and waiting lists for certain events
            event['event_registration_state'] = update_params[:status]
          end
        end

        lane.lane_details['comment'] = update_params[:comment] if update_params[:comment].present?
        lane.lane_details['admin_comment'] = update_params[:admin_comment] if update_params[:admin_comment].present?

        if update_params[:event_ids].present? && update_params[:status] != 'cancelled'
          lane.update_events(update_params[:event_ids])
        end
      end
      lane
    end
    # TODO: In the future we will need to check if any of the other lanes have a status set to accepted
    updated_guests = if update_params[:guests].present?
                       update_params[:guests]
                     else
                       guests
                     end
    updated_values = update_attributes!(lanes: updated_lanes, competing_status: competing_lane.lane_state, guests: updated_guests)
    if has_waiting_list_changed
      # Update waiting list caches
      Rails.cache.delete("#{competition_id}-waiting_list_registrations")
      Rails.cache.delete("#{competition_id}-waiting_list_boundaries")
      competing_lane.get_waiting_list_boundaries(competition_id)
    end
    updated_values
  end

  def init_payment_lane(amount, currency_code, id)
    payment_lane = LaneFactory.payment_lane(amount, currency_code, id)
    update_attributes(lanes: lanes.append(payment_lane))
  end

  def update_payment_lane(id, iso_amount, currency_iso, status)
    updated_lanes = lanes.map do |lane|
      if lane.lane_name == 'payment'
        old_details = lane.lane_details
        # TODO: Should we only add payments to the payment_history
        # if there is a new payment_id?
        lane.lane_details['payment_history'].append({
                                                      status: lane.lane_state,
                                                      payment_id: old_details['payment_id'],
                                                      currency_code: old_details['currency_code'],
                                                      amount_lowest_denominator: old_details['amount_lowest_denominator'],
                                                      last_updated: old_details['last_updated'],
                                                    })
        lane.lane_state = status
        lane.lane_details['payment_id'] = id
        lane.lane_details['amount_lowest_denominator'] = iso_amount
        lane.lane_details['currency_code'] = currency_iso
        lane.lane_details['last_updated'] = Time.now
      end
      lane
    end
    update_attributes!(lanes: updated_lanes)
  end

  def update_waiting_list(lane, update_params)
    update_params[:waiting_list_position]&.to_i
    lane.add_to_waiting_list(competition_id) if update_params[:status] == 'waiting_list'
    lane.accept_from_waiting_list if update_params[:status] == 'accepted'
    lane.remove_from_waiting_list(competition_id) if update_params[:status] == 'cancelled' || update_params[:status] == 'pending'
    lane.move_within_waiting_list(competition_id, update_params[:waiting_list_position].to_i) if
      update_params[:waiting_list_position].present? && update_params[:waiting_list_position] != competing_waiting_list_position
  end

  # Fields
  field :user_id, :integer
  field :guests, :integer
  field :competition_id, :string
  field :competing_status, :string
  field :hide_name_publicly, :boolean
  field :lanes, :array, of: Lane
  # We only do this one way because Dynamoid doesn't allow us to overwrite the foreign_key for has_one see https://github.com/Dynamoid/dynamoid/issues/740
  belongs_to :history, class: RegistrationHistory, foreign_key: :attendee_id

  global_secondary_index hash_key: :user_id, projected_attributes: :all
  global_secondary_index hash_key: :competition_id, projected_attributes: :all

  private

    def set_competing_status
      self.competing_status = competing_lane&.lane_state
    end

    def competing_status_consistency
      errors.add(:competing_status, '') unless competing_status == competing_lane&.lane_state
    end

    def waiting_list_changed?(update_params)
      waiting_list_position_changed?(update_params) || waiting_list_status_changed?(update_params)
    end

    def waiting_list_position_changed?(update_params)
      return false unless update_params[:waiting_list_position].present?
      update_params[:waiting_list_position] != competing_waiting_list_position
    end

    def waiting_list_status_changed?(update_params)
      lane_state_present = competing_status == 'waiting_list' || update_params[:status] == 'waiting_list'
      states_are_different = competing_status != update_params[:status]
      lane_state_present && states_are_different
    end
end
