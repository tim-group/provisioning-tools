require 'provisioning-tools/util/xml_utils'

describe Util::VirshDomainXmlDiffer do
  it 'fails if xml node name is different' do
    xml_diff = Util::VirshDomainXmlDiffer.new("<foo/>", "<bar/>")
    xml_diff.differences.should eql(["Node name difference. Expected: /foo Actual: /bar"])
  end

  it 'describes where text is missing' do
    expected = "<a>foo</a>"
    actual = "<a/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Node value difference. Expected /a to have text \"foo\", but it had no text."])
  end

  it 'describes where text is unexpected' do
    expected = "<a/>"
    actual = "<a>foo</a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Node value difference. Expected /a to have no text, but it had text \"foo\"."])
  end

  it 'describes where text is different' do
    expected = "<a>foo</a>"
    actual = "<a>bar</a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql(["Node value difference. Expected /a to have text \"foo\", but it had text \"bar\"."])
  end

  it 'describes where attributes are missing' do
    expected = "<a foo='one'/>"
    actual = "<a/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Attribute difference. Expected /a to have attribute \"foo=one\", but it had no attribute \"foo\"."])
  end

  it 'describes where attributes are unexpected' do
    expected = "<a/>"
    actual = "<a foo='two'/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Attribute difference. Expected /a to have no attribute \"foo\", but it had attribute \"foo=two\"."])
  end

  it 'describes where attributes are different' do
    expected = "<a foo='one'/>"
    actual = "<a foo='two'/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    xml_diff.differences.should eql(["Attribute difference. Expected /a to have attribute \"foo=one\", but it had attribute \"foo=two\"."])
  end

  it 'describes where elements are missing' do
    expected = "<a><b/><b/></a>"
    actual = "<a><b/><b/><b/></a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql(["Inconsistent Children. Expected /a to have children [\"b\", \"b\"] but it has children [\"b\", \"b\", \"b\"]"])
  end

  it 'diffs complex stuff' do
    expected = File.open(File.join(File.dirname(__FILE__), "example1.xml")).read
    actual = File.open(File.join(File.dirname(__FILE__), "example2.xml")).read

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    xml_diff.differences.should eql(["Attribute difference. Expected /domain/devices/interface/address to have attribute \"type=pci\", but it had attribute \"type=scsi\"."])
  end
end
