require 'provisioning-tools/util/namespace'

class Util::VirshDomainXmlDiffer

  def initialize(expected, actual)
    require "rexml/document"

    @expected = REXML::Document.new(expected)
    @actual = REXML::Document.new(actual)
  end

  def differences()
    expected_string = ""
    @expected.write(:output => expected_string, :indent => 0)

    actual_string = ""
    @actual.write(:output => actual_string, :indent => 0)

    expected_string == actual_string ? [] : ["different"]
  end

end