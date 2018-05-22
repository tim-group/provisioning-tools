require 'provisioning-tools/util/namespace'
require 'set'

class Util::VirshDomainXmlDiffer

  attr_reader :differences

  def initialize(expected, actual)
    require "rexml/document"
    @differences = []
    diff(REXML::Document.new(expected).root, REXML::Document.new(actual).root)
  end

  private

  def diff(exp, act, path = "")
    nodepath = "#{path}/#{exp.name}"
    STDERR.puts(nodepath)

    if exp.name != act.name
      @differences.push("Node name difference. Expected: #{nodepath} Actual: #{path}/#{act.name}")
      return
    end

    if exp.has_text? != act.has_text? || (exp.has_text? && act.has_text? && exp.get_text.value != act.get_text.value)
      @differences.push("Node value difference. Expected #{nodepath}"\
                        " to have #{exp.has_text? ? "text \"#{exp.get_text.value}\"" : "no text"},"\
                        " but it had #{act.has_text? ? "text \"#{act.get_text.value}\"" : "no text"}.")
    end

    diff_attributes(exp.attributes, act.attributes, nodepath)
    diff_children(exp.elements, act.elements, nodepath)

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
    names.each { |name| diff_attribute(name, exp[name], act[name], path) }
  end

  def diff_attribute(name, exp, act, path)
    STDERR.puts("- #{name}: #{exp}=#{act}")
    if exp != act
      STDERR.puts("!!!!")
      @differences.push("Attribute difference. Expected #{path}"\
                        " to have #{exp.nil? ? "no attribute \"#{name}\"" : "attribute \"#{name}=#{exp}\""},"\
                        " but it had #{act.nil? ? "no attribute \"#{name}\"" : "attribute \"#{name}=#{act}\""}.")
    end
  end

  def diff_children(exp, act, path)
    exp_names = names(exp)
    act_names = names(act)
    if exp_names != act_names
      @differences.push("Inconsistent Children. Expected #{path}"\
                        " to have children #{exp_names}"\
                        " but it has children #{act_names}")
      return
    end

    for i in 1..exp_names.size do
      diff(exp[i], act[i], path)
    end
  end

  def names(elements)
    names = []
    elements.each do |element|
      names.push(element.name)
    end
    names
  end
end