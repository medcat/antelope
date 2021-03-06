# encoding: utf-8

module Antelope
  class Grammar
    # Defines a production.
    Production = Struct.new(:label, :items, :block, :prec, :id) do
      # @!attribute [rw] label
      #   The label (or left-hand side) of the production.  This
      #   should be a nonterminal.
      #
      #   @return [Symbol]
      # @!attribute [rw] items
      #   The body (or right-hand side) of the production.  This can
      #   be array of terminals and nonterminals.
      #
      #   @return [Array<Token>]
      # @!attribute [rw] block
      #   The block of code to be executed when the production's right
      #   hand side is reduced.
      #
      #   @return [String]
      # @!attribute [rw] prec
      #   The precedence declaration for the production.
      #
      #   @return [Ace::Precedence]
      # @!attribute [rw] id
      #   The ID of the production.  The starting production always
      #   has an ID of 0.
      #
      #   @return [Numeric]

      # Creates a new production from a hash.  The hash's keys
      # correspond to the attributes on this class.
      #
      # @param hash [Hash<(Symbol, Object)>]
      def self.from_hash(hash)
        new(hash[:label] || hash['label'],
            hash[:items] || hash['items'],
            hash[:block] || hash['block'],
            hash[:prec]  || hash['prec'],
            hash[:id]    || hash['id'])
      end

      # Create a new version of the production with duplicated values.
      #
      # @return [Production]
      def clone
        Production.new(label.dup,
          items.map(&:dup),
          block.dup,
          prec.dup,
          id)
      end
    end
  end
end
