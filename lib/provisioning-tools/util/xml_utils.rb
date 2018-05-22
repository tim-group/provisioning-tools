require 'provisioning-tools/util/namespace'
require 'set'

class Util::VirshDomainXmlDiffer
  attr_reader :differences

  def initialize(expected, actual)
    require "rexml/document"
    @differences = []
    @exclusions = Set[
        "/domain/devices/interface/mac/@address"
    ]
    diff_element(REXML::Document.new(expected).root, REXML::Document.new(actual).root)
  end

  private

  def diff_element(exp, act, path = "")
    nodepath = "#{path}/#{exp.name}"

    if exp.name != act.name
      @differences.push("Node name difference. Expected: #{nodepath} Actual: #{path}/#{act.name}")
      return
    end

    if exp.has_text? != act.has_text? || (exp.has_text? && act.has_text? && exp.get_text.value != act.get_text.value)
      @differences.push("Node value difference. Expected #{nodepath}"\
                        " to have #{exp.has_text? ? "text \"#{exp.get_text.value}\"" : 'no text'},"\
                        " but it has #{act.has_text? ? "text \"#{act.get_text.value}\"" : 'no text'}.")
    end

    diff_attributes(exp.attributes, act.attributes, nodepath)
    diff_elements(exp.elements, act.elements, nodepath)

    @differences
  end

  def diff_attributes(exp, act, path)
    names = Set[]
    exp.each do |name, _|
      names.add(name)
    end
    act.each do |name, _|
      names.add(name)
    end
    names = names.delete_if { |name| @exclusions.include?("#{path}/@#{name}") }
    names.each { |name| diff_attribute(name, exp[name], act[name], path) }
  end

  def diff_attribute(name, exp, act, path)
    @differences.push("Attribute difference. Expected #{path}" \
                      " to have #{exp.nil? ? "no attribute \"#{name}\"" : "attribute \"#{name}=#{exp}\""}," \
                      " but it has #{act.nil? ? "no attribute \"#{name}\"" : "attribute \"#{name}=#{act}\""}.") \
                      if exp != act
  end

  def diff_elements(exp, act, path)
    exp_names = names(exp)
    act_names = names(act)
    if exp_names != act_names
      @differences.push("Inconsistent Children. Expected #{path}"\
                        " to have children #{exp_names},"\
                        " but it has children #{act_names}.")
      return
    end

    (1..exp_names.size).each { |i| diff_element(exp[i], act[i], path) }
  end

  def names(elements)
    names = []
    elements.each do |element|
      names.push(element.name)
    end
    names
  end
end
