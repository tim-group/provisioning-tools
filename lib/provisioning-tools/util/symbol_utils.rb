module Util
end

class Util::SymbolUtils
  def symbolize_keys(hash)
    transform_keys(hash) { |key| key.to_sym }
  end

  private

  def transform_keys(hash, &transformation)
    Hash[hash.map do |key, value|
      [transformation.call(key), value.kind_of?(Hash) ? transform_keys(value, &transformation) : value]
    end]
  end
end
