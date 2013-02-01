module Util
end

class Util::SymbolUtils
  def symbolize_keys(hash)
    return transform_keys(hash) do |key|
      key.to_sym
    end
  end

  def stringify_keys(hash)
    return transform_keys(hash) do |key|
      key.to_s
    end
  end

  def transform_keys(hash, &transformation)
    return Hash[hash.map do |key, value|
      [transformation.call(key), value.kind_of?(Hash) ? transform_keys(value, &transformation) : value]
    end]
  end
end
