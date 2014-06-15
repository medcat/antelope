require "antelope/generation/recognizer/rule"
require "antelope/generation/recognizer/state"

module Antelope
  module Generation
    class Recognizer

      attr_reader :states
      attr_reader :start
      attr_reader :parser

      def initialize(parser)
        @parser = parser
        @states = Set.new
      end

      def call
        @states = Set.new
        @start  = compute_initial_state
        redefine_state_ids
        redefine_rule_ids
        parser.states = states
      end

      def compute_initial_state
        production = parser.productions[:$start][0]
        rule = Rule.new(production, 0)
        compute_whole_state(rule)
      end

      def compute_whole_state(rule)
        state = State.new
        state << rule
        compute_closure(state)
        states << state
        compute_states
        state
      end

      def compute_states
        fixed_point(states) do
          states.dup.each do |state|
            state.rules.each do |rule|
              next unless rule.succ?
              transitional = find_state_for(rule.succ) do |succ|
                ns = State.new
                ns << succ
                compute_closure(ns)
                states << ns
                ns
              end

              if state.transitions[rule.active.name]
                state.transitions[rule.active.name].merge! transitional
              else
                state.transitions[rule.active.name] = transitional
              end
            end
          end
        end
      end

      def compute_closure(state)
        fixed_point(state.rules) do
          state.rules.select { |_| _.active.nonterminal? }.each do |rule|
            parser.productions[rule.active.name].each do |prod|
              state << Rule.new(prod, 0)
            end
          end
        end
      end

      private

      def find_state_for(rule)
        states.find { |state| state.include?(rule) } or yield(rule)
      end

      def redefine_state_ids
        states.each_with_index do |state, i|
          state.id = i
        end
      end

      def redefine_rule_ids
        start = 0

        states.each do |state|
          state.rules.each do |rule|
            rule.id = start
            start  += 1
          end
        end
      end

      def fixed_point(enum)
        added = 1

        until added.zero?
          added = enum.size
          yield
          added = enum.size - added
        end
      end

    end
  end
end