# encoding: utf-8

require "rubygems/requirement"

module Antelope
  module Ace

    # Compiles a set of tokens generated by {Scanner}.  These tokens
    # may not nessicarily have been generated by {Scanner}, however
    # the tokens must follow the same rules even still.
    #
    # A list of all tokens that this compiler accepts:
    #
    # - `:directive` (2 arguments)
    # - `:copy` (1 argument)
    # - `:second` (no arguments)
    # - `:label` (2 arguments)
    # - `:part` (2 arguments)
    # - `:or` (no arguments)
    # - `:prec` (1 argument)
    # - `:block` (1 argument)
    # - `:third` (no arguments)
    # - `:body` (1 argument)
    #
    # The tokens are handled by methods that follow the rule
    # `compile_<token name>`.
    class Compiler

      # The body of the output compiler.  This should be formatted in
      # the language that the parser is to be written in.  Some output
      # generators may have special syntax that allows the parser to
      # be put in the body; see the output generators for more.
      #
      # @return [String]
      attr_accessor :body

      # A list of all the rules that are defined in the file.  The
      # rules are defined as such:
      #
      # - **`label`** (`Symbol`) &mdash; The left-hand side of the rule;
      #   this is the nonterminal that the right side reduces to.
      # - **`set`** (`Array<Symbol>`) &mdash; The right-hand side of the
      #   rule.  This is a combination of terminals and nonterminals.
      # - **`block`** (`String`) &mdash; The code to be run on a reduction.
      #   this should be formatted in the language that the output
      #   parser is written in.  Optional; default value is `""`.
      # - **`prec`** (`String`) &mdash; The precedence level for the
      #   rule.  This should be a nonterminal or terminal.  Optional;
      #   default value is `""`.
      #
      # @return [Array<Hash>]
      attr_accessor :rules

      # Options defined by directives in the first part of the file.
      #
      # - **`:terminals`** (`Array<Symbol, String?>)` &mdash; A list
      #   of all of the terminals in the language.  If this is not
      #   properly defined, the grammar will throw an error saying
      #   that a symbol used in the grammar is not defined.
      # - **`:prec`** (`Array<(Symbol, Array<Symbol>)>`) &mdash; A list
      #   of the precedence rules of the grammar.  The first element
      #   of each element is the _type_ of precedence (and should be
      #   any of `:left`, `:right`, or `:nonassoc`), and the second
      #   element should be the symbols that are on that level.
      # - **`:type`** (`String`) &mdash; The type of generator to
      #   generate; this should be a language.
      # - **`:extra`** (`Hash<Symbol, Array<Object>>`) &mdash; Extra
      #   options that are not defined here.
      # @return [Hash]
      attr_accessor :options

      # Creates a compiler, and then runs the compiler.
      #
      # @param (see #initialize)
      # @see #compile
      # @return [Compiler] the compiler.
      def self.compile(tokens)
        new(tokens).compile
      end

      # Initialize the compiler.  The compiler keeps track of a state;
      # this state is basically which part of the file we're in.  The
      # state can be `:first`, `:second`, or `:third`; some tokens
      # may not exist in certain states.
      #
      # @param tokens [Array<Array<(Symbol, Object, ...)>>] the tokens
      #   from the {Scanner}.
      def initialize(tokens)
        @tokens   = tokens
        @body     = ""
        @state    = :first
        @rules    = []
        @current  = nil
        @current_label = nil
        @options  = {
          :terminals    => [],
          :nonterminals => [],
          :prec         => [],
          :type         => nil,
          :extra        => Hashie::Extensions::IndifferentAccess.
            inject!({})
        }
      end

      # Pretty inspect.
      #
      # @return [String]
      # def inspect
      #   "#<#{self.class} state=#{@state.inspect} options=#{options.inspect}>"
      # end

      # Runs the compiler on the input tokens.  For each token,
      # it calls `compile_<type>` with `<type>` being the first
      # element of the token, with the remaining part of the array
      # passed as arguments.
      #
      # @return [self]
      def compile
        @tokens.each do |token|
          send(:"compile_#{token[0]}", *token[1..-1])
        end

        self
      end

      # Compiles a directive.  This may only be triggered in the first
      # section of the file.  The directive accepts two arguments. The
      # directive name can be any of the following:
      #
      # - `:terminal` &mdash; adds a terminal.  Requires 1-2
      #   arguments; the first argument is the terminal name, and the
      #   second argument is a string that can represent the terminal.
      # - `:require` &mdash; requires a certain version of Antelope.
      #   Requires 1 argument.  If the first argument is a version
      #   greater than the current version of Antelope, it raises
      #   an error.
      # - `:left` &mdash; creates a new precedence level, with the
      #   argument values being the symbols.  The precedence level
      #   is left associative.
      # - `:right` &mdash; creates a new precedence level, with the
      #   argument valeus being the symbols.  The precedence level
      #   is right associative.
      # - `:nonassoc` &mdash; creates a nre precedence level, with the
      #   argument values being the symbols.  The precedence level
      #   is nonassociative.
      # - `:type` &mdash; the type of parser to generate.  This should
      #   correspond to the output language of the parser.
      #
      # @param name [String, Symbol] the name of the directive.
      #   Accepts any of `:terminal`, `:require`, `:left`, `:right`,
      #   `:nonassoc`, and `:type`.  Any other values produce an
      #   error on stderr and are put in the `:extra` hash on
      #   {#options}.
      # @param args [Array<String>] the arguments to the directive.
      # @return [void]
      # @see #options
      def compile_directive(name, args)
        require_state! :first
        name = name.intern
        case name
        when :terminal, :token
          handle_token(args)
        when :require
          compare_versions(args[0])
        when :left, :right, :nonassoc
          options[:prec] << [name, *args.map(&:intern)]
        when :language, :generator, :"grammar.type"
          options[:type] = args[0].downcase
        when :type
          raise SyntaxError, "%type directive requires first " \
            "argument to be caret" unless args[0].caret?

          options[:nonterminals] <<
            [args[0], args[1..-1].map(&:intern)]
        when :define
          compile_extra(args[0], args[1..-1])
        else
          compile_extra(name, args)
        end
      end

      def compile_extra(name, args)
        matching = Generator.directives[name.to_s]

        raise NoDirectiveError, "no directive named #{name}" \
          unless matching

        options[:extra][name] = args
      end

      # Compiles a copy token.  A copy token basically copies its
      # argument directly into the body.  Used in both the first
      # and third parts.
      #
      # @param body [String] the string to copy into the body.
      # @return [void]
      def compile_copy(body)
        require_state! :first, :third
        @body << body
      end

      # Sets the state to the second part.
      #
      # @return [void]
      def compile_second
        @state = :second
      end

      # Compiles a label.  This starts a rule definition.  The token
      # should only exist in the second part.  A rule definition
      # occurs by setting the `@current_label` to the first argument,
      # and `@current` to a blank rule save the label set.  If a
      # rule definition was already in progress, it is completed.
      #
      # @param label [String] the left-hand side of the rule; it
      #   should be a nonterminal.
      # @return [void]
      def compile_label(label, val)
        require_state! :second
        if @current
          @rules << @current
        end

        label = label.intern
        @current_label = [label, val]

        @current = {
          label: label,
          label_id: val,
          set:   [],
          block: "",
          prec:  ""
        }
      end

      # Compiles a part.  This should only occur during a rule
      # definition.  The token should only exist in the second part.
      # It adds the first argument to the set of the current rule.
      #
      # @param text [String] the symbol to append to the current rule.
      def compile_part(text, val)
        require_state! :second
        @current[:set] << [text.intern, val]
      end

      # Compiles an or.  This should only occur in a rule definition,
      # and in the second part.  It starts a new rule definition by
      # calling {#compile_label} with the current label.
      #
      # @return [void]
      # @see #compile_label
      def compile_or
        compile_label(*@current_label)
      end

      # Compiles the precedence operator.  This should only occur in a
      # rule definition, and in the second part.  It sets the
      # precedence definition on the current rule.
      #
      # @param prec [String] the precedence of the rule.
      # @return [void]
      def compile_prec(prec)
        require_state! :second
        @current[:prec] = prec
      end

      # Compiles a block.  This should only occur in a rule
      # definition, and in the second part.  It sets the block on the
      # current rule.
      #
      # @param block [String] the block.
      # @return [void]
      def compile_block(block)
        require_state! :second
        @current[:block] = block
      end

      # Sets the state to the third part.  If a rule definition was
      # in progress, it finishes the rule.
      #
      # @return [void]
      def compile_third
        if @current
          @rules << @current
          @current_label = @current = nil
        end

        @state = :third
      end

      private

      def handle_token(args)
        type = ""
        if args[0].caret?
          type = args.shift
        end

        name = args.shift
        value = args.shift

        options[:terminals] << [name.intern, type, nil, value]
      end

      # Checks the current state against the given states.
      #
      # @raise [InvalidStateError] if none of the given states match
      #   the current state.
      # @return [void]
      def require_state!(*state)
        raise InvalidStateError,
          "In state #{@state}, " \
          "required state #{state.join(", ")}" \
          unless state.include?(@state)
      end

      # Compares the required version and the Antelope version.
      #
      # @raise [IncompatibleVersionError] if the Antelope version
      #   doesn't meet the requirement.
      # @return [void]
      def compare_versions(required)
        antelope_version = Gem::Version.new(Antelope::VERSION)
        required_version = Gem::Requirement.new(required)

        unless required_version =~ antelope_version
          raise IncompatibleVersionError,
            "Grammar requires #{required}, " \
            "have #{Antelope::VERSION}"
        end
      end
    end
  end
end
