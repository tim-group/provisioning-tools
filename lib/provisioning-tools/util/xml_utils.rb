require 'provisioning-tools/util/namespace'
require 'set'

class Util::VirshDomainXmlDiffer
  attr_reader :differences

  def initialize(expected, actual)
    require "rexml/document"
    @differences = []
    @exclusions = Set[
        "/domain/@id",                            # generated vm id
        "/domain/uuid",                           # generated vm uuid
        "/domain/resource",                       # we use default resource partition
        "/domain/seclabel",                       # generated security labels for apparmor
        "/domain/devices/interface/mac/@address"  # generated mac addresses of interfaces
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
    exp_names = names(exp, path)
    act_names = names(act, path)
    names = exp_names.to_set + act_names.to_set

    exp_counts = exp_names.group_by { |a| a }.map { |a, b| [a, b.size] }.to_h
    act_counts = act_names.group_by { |a| a }.map { |a, b| [a, b.size] }.to_h
    counts = names.map { |name| [name, exp_counts.fetch(name, 0), act_counts.fetch(name, 0)] }

    diffs = counts.select { |v| v[1] != v[2] }
    diffs.each do |diff|
      diff_type = diff[1] > diff[2] ? "Missing" : "Unexpected"
      @differences.push "#{diff_type} element \"#{path}/#{diff[0]}\" (expected #{diff[1]}, actual #{diff[2]})."
    end

    sames = counts.select { |v| v[1] == v[2] }.map { |same| same[0] }
    sames.to_set.each { |name| exp.to_a(name).zip(act.to_a(name)).each { |e, a| diff_element(e, a, path) } }
  end

  def names(elements, path)
    names = []
    elements.each do |element|
      names.push(element.name) unless @exclusions.include?("#{path}/#{element.name}")
    end
    names
  end
end
