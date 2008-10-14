#!env ruby
require 'html2textile'
require 'open-uri'

if ARGV.empty?
  puts "parse <input> <output>"
  exit(1)
end

parser = HTMLToTextileParser.new
file = open(ARGV.first)
parser.feed(file.read)
output = (ARGV.size > 1) ? open(ARGV.last,'w') : STDOUT
output.write parser.to_textile
