module Antelope
  module Generator
    class Conflictor
      Conflict = Struct.new(:state, :type, :rules, :token)
    end
  end
end