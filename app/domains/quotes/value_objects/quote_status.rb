# frozen_string_literal: true

module Quotes
  module ValueObjects
    class QuoteStatus
      STATES = %i[created sent approved rejected cancelled].freeze

      TRANSITIONS = {
        # cancelled: compensação da Saga, quando a OS é cancelada
        created: %i[sent cancelled],
        sent: %i[approved rejected cancelled],
        approved: %i[cancelled],
        rejected: [],
        cancelled: []
      }.freeze

      attr_reader :value

      def initialize(value = :created)
        @value = value.to_sym
        raise ArgumentError, "Invalid status: #{value}" unless STATES.include?(@value)
      end

      def can_transition_to?(new_state)
        TRANSITIONS[@value].include?(new_state.to_sym)
      end

      def transition_to(new_state)
        new_state = new_state.to_sym
        raise "Invalid transition from #{@value} to #{new_state}" unless can_transition_to?(new_state)

        self.class.new(new_state)
      end

      def terminal?
        TRANSITIONS[@value].empty?
      end

      def ==(other)
        other.is_a?(self.class) && other.value == value
      end

      alias eql? ==

      def hash
        [ self.class, value ].hash
      end

      def to_s
        value.to_s
      end

      def to_sym
        value
      end
    end
  end
end
