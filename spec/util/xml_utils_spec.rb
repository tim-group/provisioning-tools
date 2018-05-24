require 'provisioning-tools/util/xml_utils'

describe Util::VirshDomainXmlDiffer do
  it 'fails if xml node name is different' do
    xml_diff = Util::VirshDomainXmlDiffer.new("<foo/>", "<bar/>")
    expect(xml_diff.differences).to match_array(["Node name difference. Expected: /foo Actual: /bar"])
  end

  it 'describes where text is missing' do
    expected = "<a>foo</a>"
    actual = "<a/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array(["Node value difference. Expected /a to have text \"foo\", but it has no text."])
  end

  it 'describes where text is unexpected' do
    expected = "<a/>"
    actual = "<a>foo</a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array(["Node value difference. Expected /a to have no text, but it has text \"foo\"."])
  end

  it 'describes where text is different' do
    expected = "<a>foo</a>"
    actual = "<a>bar</a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    expect(xml_diff.differences).to match_array(["Node value difference. Expected /a to have text \"foo\", but it has text \"bar\"."])
  end

  it 'ignores where text is blank' do
    expected = "<a></a>"
    actual = "<a>         \n      </a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    expect(xml_diff.differences).to match_array([])
  end

  it 'describes where attributes are missing' do
    expected = "<a foo='one'/>"
    actual = "<a/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array([
      "Attribute difference. Expected /a to have attribute \"foo=one\", but it has no attribute \"foo\"."
    ])
  end

  it 'describes where attributes are unexpected' do
    expected = "<a/>"
    actual = "<a foo='two'/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array([
      "Attribute difference. Expected /a to have no attribute \"foo\", but it has attribute \"foo=two\"."
    ])
  end

  it 'describes where attributes are different' do
    expected = "<a foo='one'/>"
    actual = "<a foo='two'/>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array([
      "Attribute difference. Expected /a to have attribute \"foo=one\", but it has attribute \"foo=two\"."
    ])
  end

  it 'describes where elements are missing' do
    expected = "<a><b/><b/><b/></a>"
    actual = "<a><b/><b/></a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    expect(xml_diff.differences).to match_array(["Missing element \"/a/b\" (expected 3, actual 2)."])
  end

  it 'describes where elements are unexpected' do
    expected = "<a><b/><b/></a>"
    actual = "<a><b/><b/><b/></a>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    expect(xml_diff.differences).to match_array(["Unexpected element \"/a/b\" (expected 2, actual 3)."])
  end

  it 'diffs complex stuff' do
    expected = File.open(File.join(File.dirname(__FILE__), "example1.xml")).read
    actual = File.open(File.join(File.dirname(__FILE__), "example2.xml")).read

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)

    expect(xml_diff.differences).to match_array([
      "Unexpected element \"/domain/clock\" (expected 0, actual 1).",
      "Missing element \"/domain/devices/input\" (expected 2, actual 1).",
      "Attribute difference. Expected /domain/devices/interface/address to have attribute \"type=pci\", but it has attribute \"type=scsi\"."
    ])
  end

  it 'ignores excluded things' do
    expected = "<domain>"\
               "  <devices>"\
               "    <interface type='bridge'>"\
               "      <mac/>"\
               "    </interface>"\
               "  </devices>"\
               "</domain>"
    actual = "<domain id='4'>"\
             "  <uuid>beef</uuid>"\
             "  <resource/>"\
             "  <seclabel/>"\
             "  <devices>"\
             "    <interface type='bridge'>"\
             "      <mac address='dead'/>"\
             "    </interface>"\
             "    <input type='keyboard' bus='ps2'/>"\
             "  </devices>"\
             "</domain>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array([])
  end

  it 'checks things that are not ignored, but are similar to those that are ignored' do
    expected = "<domain>"\
               "  <id>4</id>"\
               "  <devices>"\
               "    <uuid>fee</uuid>"\
               "  </devices>"\
               "</domain>"
    actual = "<domain idx='4'>"\
             "  <id>5</id>"\
             "  <devices>"\
             "    <uuid>beef</uuid>"\
             "    <input type='mouse' bus='ps2'/>"\
             "  </devices>"\
             "</domain>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array([
      "Attribute difference. Expected /domain to have no attribute \"idx\", but it has attribute \"idx=4\".",
      "Node value difference. Expected /domain/id to have text \"4\", but it has text \"5\".",
      "Unexpected element \"/domain/devices/input\" (expected 0, actual 1).",
      "Node value difference. Expected /domain/devices/uuid to have text \"fee\", but it has text \"beef\"."
    ])
  end

  it 'applies default values where they are not present' do
    expected = "<domain>"\
               "  <memory unit='KiB'/>"\
               "</domain>"
    actual = "<domain>"\
             "  <memory/>"\
             "</domain>"

    expect(Util::VirshDomainXmlDiffer.new(expected, actual).differences).to match_array([])
    expect(Util::VirshDomainXmlDiffer.new(actual, expected).differences).to match_array([])
  end

  it 'does not apply default values where they are present' do
    expected = "<domain>"\
               "  <memory unit='b'/>"\
               "</domain>"
    actual = "<domain>"\
             "  <memory/>"\
             "</domain>"

    xml_diff = Util::VirshDomainXmlDiffer.new(expected, actual)
    expect(xml_diff.differences).to match_array([
      "Attribute difference. Expected /domain/memory to have attribute \"unit=b\", but it has attribute \"unit=KiB\"."
    ])
  end
end
