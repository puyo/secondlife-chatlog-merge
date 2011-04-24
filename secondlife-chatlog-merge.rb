#!/usr/bin/env ruby1.8

require 'pathname'
require 'pp'
require 'time'
require 'fileutils'

class LogInput
  attr_reader :time

  def initialize(path)
    @time = Time.local(2000, 1, 1)
    @path = Pathname.new(path.to_s)
    @file = @path.open
    read_line
  end

  def <=>(other)
    @time <=> other.time
  end

  def finished?
    @line.nil?
  end

  def read_line
    @line = @file.gets
    if @line.nil?
      @time = nil
    elsif match = /^\[(.+?)\]/.match(@line)
      @time = Time.parse(match.captures.first)
    end
  end

  def line
    result = @line
    read_line
    result
  end

  def lines_up_to(up_to_time)
    result = []
    while not finished? and @time and @time <= up_to_time
      result << line
    end
    result
  end
end

def merge_logs(name, paths, outdir)
  outpath = outdir.join(name + '.txt')
  temppath = outdir.join(name + '.merge')
  if outpath.exist?
    paths = paths + [outpath]
  end
  inputs = paths.map{ |path| LogInput.new(path) }
  last_lines = []
  last_time = nil
  temppath.open('w') do |output_file|
    loop do
      inputs.delete_if(&:finished?)
      break if inputs.empty?
      time = inputs.map(&:time).min
      output = inputs.map{|input| input.lines_up_to(time) }.flatten.uniq.join('')
      if time != last_time
        last_time = time
      end
      output_file.print output
    end
  end
  FileUtils.mv(temppath, outpath)
  $stdout.print '.'
  $stdout.flush
ensure
  FileUtils.rm_f(temppath)
end

# ---
# Stuff you can change

username = ARGV.shift || raise("Must specify username")

paths = [
  "~/.secondlife/#{username}*",
  "~/.imprudence/#{username}*",
  "~/Library/SecondLife/#{username}*",
  "/windows/Users/*/Application\ Data/Imprudence/#{username}*",
]
outdir = "~/Dropbox/sl/chatlogs"

# ---

if $0 == __FILE__
  outdir = Pathname.new(outdir).expand_path
  paths = paths.map{|path| Pathname.glob(Pathname.new(path).expand_path) }.flatten.uniq

  puts "Inputs:"
  puts paths
  puts "Output:"
  puts outdir

  logs_for = Hash.new {|h,k| h[k] = [] }
  paths.each do |path|
    Pathname.glob(path.join('**/*.txt')).each do |file|
      name = file.basename('.txt').to_s
      logs_for[name] << file
    end
  end

  if ARGV.empty?
    names = logs_for.keys
  else
    names = ARGV
  end
  names.sort!

  puts "Names: #{names.join(', ')}"

  outdir.mkpath
  names.each do |name|
    paths = logs_for[name]
    merge_logs(name, paths, outdir)
  end
  puts
end
