require 'irb/completion'
require 'pp'
require 'benchmark'
require 'open-uri'
require 'ostruct'
require 'rubygems'

begin
  Dir[File.join(ENV['HOME'], 'usr/local/lib/ruby/*/lib')].each do |libdir|
    $:.unshift libdir
  end
  require 'json'
  require 'ods/client'
rescue LoadError
end

IRB.conf[:USE_READLINE] = true

module TwitterUtil
  def User(id_or_screen_name)
    OpenStruct(JSON.parse(`twurl /1/users/show/#{id_or_screen_name}.json`))
  end

  def Tweet(id)
    OpenStruct(JSON.parse(open("http://api.twitter.com/1/statuses/show/#{id}.json").read))
  end

  class Hash
    def to_open_struct
      OpenStruct(self)
    end
  end

  def OpenStruct(hash)
    struct = OpenStruct.new

    if hash.has_key?(:id) || hash.has_key?('id')
      class << struct
        undef :id
      end
    end

    hash.each do |attribute, value|
      value = value.is_a?(Hash) ? OpenStruct(value) : value
      struct.send("#{attribute}=", value)
    end
    struct
  end
end
include TwitterUtil

def ods(query)
  @client ||= ODS::Client.new
  @client.user(query)
end

class Hash
  class << self
    def default(val)
      new {|hash, key| hash[key] = val }
    end
  end
end

module Enumerable
  def count_by
    inject(Hash.default(0)) do |hash, item|
      hash[yield(item)] += 1
      hash
    end
  end
end

module Kernel
  def __measure__(&block)
    Benchmark.bm do |x|
      x.report(&block)
    end
  end

  def include_all_modules_from(parent_module)
    parent_module.constants.each do |const|
      mod = parent_module.const_get(const)
      if mod.class == Module
        send(:include, mod)
        include_all_modules_from(mod)
      end
    end
  end
  
  def m(object = Object.new, pattern = nil)
    methods = object.public_methods(false).sort
    methods = methods.grep pattern unless pattern.nil?
    ObjectMethods.new(methods)
  end
  
  class ObjectMethods < Array
    def inspect
      puts sort
    end
  end
end

class Numeric
  SCALE_TO_WORD = Hash.new do |h, i|
    " * 10^#{i * 3}"
  end
  
  SCALE_TO_WORD.merge!(
    1  => " thousand",
    2  => " million",
    3  => " billion",
    4  => " trillion"
  )

  def cardinality(figures = 3)
    scale = (Math.log10(self) / 3).floor
    base = 1000 ** scale
    suffix = SCALE_TO_WORD[scale.abs]
    suffix = "#{suffix}ths" if scale < 1 && suffix
    sprintf("%.#{ figures }G", to_f / base) + suffix.to_s
  end
end

class Object
  def _(instance_variable)
    instance_variable_get "@#{instance_variable}"
  end
end

def ri arg
  puts `ri #{arg}`
end

class Module
  def ri(meth = nil)
    if meth
      if instance_methods(false).include? meth.to_s
        puts `ri #{self}##{meth}`
      end
    else
      puts `ri #{self}`
    end
  end
end

@histfile = "~/.irb.hist"
@maxhistsize = 100

if defined? Readline::HISTORY
  histfile = File::expand_path(@histfile)
  if File::exist?(histfile)
    lines = IO::readlines( histfile ).collect {|line| line.chomp}
    Readline::HISTORY.push(*lines)
  end

  Kernel::at_exit do
    lines = Readline::HISTORY.to_a.reverse.uniq.reverse
    lines = lines[ -@maxhistsize, @maxhistsize ] if lines.compact.size > @maxhistsize
    File::open(histfile, File::WRONLY|File::CREAT|File::TRUNC) do |ofh|
      lines.each {|line| ofh.puts line }
    end
  end
end
