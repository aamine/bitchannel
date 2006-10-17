unless String.method_defined?(:lines)
  class String
    alias lines to_a
  end
end
