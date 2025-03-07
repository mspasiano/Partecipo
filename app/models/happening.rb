# frozen_string_literal: true

# This model manage the happenings for each {Fact}
# === Relations
# belongs to {Fact}
# has many {Ticket}
# === Validates
# * presence of {Fact}
# * presence of {start_at}
#
# @!attribute [rw] id
#   @return [Integer] unique identifier for {Happening}
# @!attribute [rw] fact_id
#   @return [Integer] identifier of related {Fact}
# @!attribute [rw] title
#   @return [String] Is an optional description for {Happening}
# @!attribute [rw] start_at
#   @return [DateTime] when the {Happening} start
# @!attribute [rw] stop_sale_at
#   @return [DateTime] since {Ticket} can no longer be sold
# @!attribute [rw] max_seats_for_ticket
#   @return [Integer] Max seats for each ticket, default is 1
# @!attribute [rw] max_seats
#   @return [integer] number of seats for the {Happening}. If is null hasn't limit
# @!attribute [rw] ticketss_count
#   @return [Integer] counter cache for {Ticket}
# @!attribute [rw] seats_count
#   @return [Integer] counter cache of sum of {Ticket.seats}
# @!attribute [rw] created_at
#   @return [DateTime] when the record was created
# @!attribute [rw] updated_at
#   @return [DateTime] when the record was updated
#
# @!method self.future()
#   @return [Array] list of [Fact] with stop_on egual or greather than Time.zone.today, ordered by pinnes asc, stop_on asc
# @!method self.history()
#   @return [Array] list of [Fact] with stop_on minor than Time.zone.today, ordered by start_on desc
class Happening < ApplicationRecord
  belongs_to :fact, counter_cache: true
  has_many   :tickets, dependent: :destroy
  validates  :fact, presence: true
  validates  :start_at, presence: true
  validates  :start_sale_at, presence: true
  validates  :stop_sale_at, presence: true
  validates  :max_seats, presence: true
  validates  :max_seats_for_ticket, presence: true
  validates :repeat_for, numericality: { greather_to: 0, only_integer: true }, on: :create

  after_create :add_repetitions

  attr_accessor :repeat_for, :repeat_in

  scope :future,  -> { where('start_at >= :from', from: Time.zone.now).order('start_at asc') }
  scope :history, -> { where('start_at < :from', from: Time.zone.now).order('start_at desc') }

  # update {seats_count} with sum of her {Ticket.seats}
  def update_seats_count!
    if persisted?
      self.seats_count = tickets.sum :seats
      save touch: false 
      broadcast_replace_to 'facts', target: "counter_happening_#{id}", partial: 'happenings/counter',  locals: { happening: self }
      broadcast_replace_to 'facts', target: "nav_fact_#{fact_id}", partial: 'facts/nav',  locals: { fact: fact }
    end
  end

  # @return [Boolean] check seaelability time
  def saleable?
    Time.zone.now >= start_sale_at && Time.zone.now <= stop_sale_at
  end

  # @return [String] unique code to identify the {Happening}
  def code
    [fact_id, id].join(' - ')
  end

  private

  # save multiple copies of the elements
  def add_repetitions
    (1..repeat_for.to_i).each do |n|
      next unless repeat_in.include?(start_at.+(n.days).wday.to_s)

      fact.happenings.create(
        detail: detail,
        start_at: start_at + n.days,
        start_sale_at: start_at + n.days,
        stop_sale_at: stop_sale_at + n.days,
        max_seats: max_seats,
        max_seats_for_ticket: max_seats_for_ticket,
        repeat_for: 0
      )
    end
  end
end
