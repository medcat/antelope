module Antelope
  module Generation
    class Constructor
      module First

        def initialize
          @firstifying = []
          super
        end

        def first(token)
          case token
          when Ace::Token::Nonterminal
            firstifying(token) do
              productions = parser.productions[token.name]
              productions.map { |prod|
                first(prod[:items]) }.inject(Set.new, :+)
            end
          when Array
            first_array(token)
          when Ace::Token::Epsilon
            Set.new
          when Ace::Token::Terminal
            Set.new([token])
          else
            incorrect_argument! token, Ace::Token, Array
          end
        end

        private

        def first_array(token)
          token.dup.delete_if { |tok| @firstifying.include?(tok) }.
          each_with_index.take_while do |tok, i|
            if i.zero?
              true
            else
              nullable?(token[i - 1])
            end
          end.map(&:first).map { |tok| first(tok) }.inject(Set.new, :+)
        end

        def firstifying(tok)
          @firstifying << tok
          out = yield
          @firstifying.delete tok
          out
        end
      end
    end
  end
end