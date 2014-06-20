# encoding: utf-8

require "set"
require "antelope/generation/constructor/nullable"
require "antelope/generation/constructor/first"
require "antelope/generation/constructor/follow"

module Antelope
  module Generation

    # Constructs the lookahead sets for all of the rules in the
    # grammar.
    class Constructor

      include Nullable
      include First
      include Follow

      # The grammar.
      #
      # @return [Ace::Grammar]
      attr_reader :grammar

      attr_reader :productions

      # Initialize.
      #
      # @param grammar [Ace::Grammar] the grammar.
      def initialize(grammar)
        @productions = Set.new
        @grammar = grammar
        super()
      end

      # Performs the construction.  First, it goes through every state
      # and augments the state.  It then goes through every rule and
      # augments it.
      #
      # @return [void]
      # @see #augment_state
      # @see #augment_rule
      def call
        grammar.states.each do |state|
          augment_state(state)
        end.each do |state|
          augment_rules(state)
        end
      end

      # Augments the given state.  On every rule within that state
      # that has a position of zero, it follows the rule throughout
      # the DFA until the end; it marks every nonterminal it
      # encounters with the transitions it took on that nonterminal.
      #
      # @param state [Recognizer::State] the state to augment.
      # @return [void]
      def augment_state(state)
        state.rules.select { |x| x.position.zero? }.each do |rule|
          current_state = state

          rule.left.from = state
          rule.left.to   = state.transitions[rule.left.name]

          rule.right.each_with_index do |part, pos|
            transition = current_state.transitions[part.name]
            if part.nonterminal?
              part.from = current_state
              part.to   = transition
            end

            current_state = transition
          end

          productions << rule
        end
      end

      # Augments every final rule.  For every rule in the current
      # state that has a position of zero, it follows the rule through
      # the DFA until the ending state; it then modifies the ending
      # state's lookahead set to be the FOLLOW set of the nonterminal
      # it reduces to.
      #
      # @param state [Recognizer::State]
      # @return [void]
      # @see Follow#follow
      def augment_rules(state)
        state.rules.select { |x| x.position.zero? }.each do |rule|
          current_state = state

          rule.right.each do |part|
            transition = current_state.transitions[part.name]
            current_state = transition
          end

          final = current_state.rule_for(rule)

          final.lookahead = follow(rule.left)
        end
      end

      private

      def incorrect_argument!(arg, *types)
        raise ArgumentError, "Expected one of #{types.join(", ")}, got #{arg.class}"
      end
    end
  end
end
