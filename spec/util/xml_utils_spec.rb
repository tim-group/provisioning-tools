require 'provisioning-tools/util/xml_utils'

describe Util::VirshDomainXmlDiffer do
  it 'fails if xml is different' do
    xml_diff = Util::VirshDomainXmlDiffer.new("<foo/>", "<bar/>")
    xml_diff.differences.size.should eql(1)
  end
end
