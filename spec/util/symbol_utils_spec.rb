require 'provisioning-tools/util/symbol_utils'

describe Util::SymbolUtils do
  it 'symbolizes keys' do
    symbol_utils = Util::SymbolUtils.new
    symbol_utils.symbolize_keys({}).should eql({})
    symbol_utils.symbolize_keys('foo' => 'bar').should eql(:foo => 'bar')
    symbol_utils.symbolize_keys(:foo => 'bar').should eql(:foo => 'bar')
    symbol_utils.symbolize_keys('foo' => { 'bar' => "bing" }).should eql(:foo => { :bar => "bing" })
  end
end
