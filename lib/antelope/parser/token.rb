module Antelope
  class Parser
    class Token
      attr_reader :value
      attr_accessor :from
      attr_accessor :to

      def initialize(value)
        @value = value
        @from  = nil
        @to    = nil
      end

      include Comparable

      def terminal?
        false
      end

      def nonterminal?
        false
      end

      def epsilon?
        false
      end

      def to_s
        buf = "" << @value.to_s
        if (from or to)
          buf << "_["
          buf << "#{from.id}" if from
          buf << ":#{to.id}"  if to
          buf << "]"
        end

        buf
      end

      def <=>(other)
        if other.is_a? Token
          to_a <=> other.to_a
        else
          super
        end
      end

      def ===(other)
        if other.is_a? Token
          without_transitions == other.without_transitions
        else
          super
        end
      end

      def without_transitions
        self.class.new(value)
      end

      def hash
        to_a.hash
      end

      alias_method :eql?, :==

      def to_a
        [to, from, terminal?, nonterminal?, epsilon?, value]
      end
    end

    class Nonterminal < Token
      def nonterminal?
        true
      end
    end
    class Terminal < Token
      def terminal?
        true
      end
    end
    class Epsilon < Token
      def initialize(*)
        super :epsilon
      end

      def epsilon?
        true
      end
    end
  end
end
