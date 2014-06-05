class MyParser < Antelope::Parser
  terminals do
    terminal NUMBER
    terminal MULTIPLY
    terminal DIVIDE
    terminal ADD
    terminal SUBTRACT
    terminal LPAREN
    terminal RPAREN
  end

  presidence do
    left MULTIPLY, DIVIDE
    left ADD, SUBTRACT
  end

  start_production :expressions

  productions do
    expressions do
      match NUMBER do |a| a.to_i end

      match expressions, ADD, expressions do |a, _, b|
        a + b
      end

      match expressions, SUBTRACT, expressions do |a, _, b|
        a - b
      end

      match expressions, MULTIPLY, expressions do |a, _, b|
        a * b
      end

      match expressions, DIVIDE, expressions do |a, _, b|
        a / b
      end

      match LPAREN, expressions, RPAREN do |_, a, _|
        a
      end
    end
  end
end

recognizer = Antelope::Recognizer.new(MyParser)
recognizer.call
c = Antelope::Constructor.new(MyParser)
c.call

File.open("example.output", "w") do |f|
  f << "productions:\n"
  c.productions.each do |rule|
    f << "#{Antelope::Output.output(rule)}"
  end

  f << "\nfollow():\n"
  c.productions.map { |x| x.left }.uniq.each do |p|
    f << "  #{p}: #{c.follow(p).to_a.join(" ")}\n"
  end

  f << "\n"
  Antelope::Output.output(recognizer.start, f)
end