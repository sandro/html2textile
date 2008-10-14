require 'sgml-parser'

# A class to convert HTML to textile. Based on the python parser
# found at http://aftnn.org/content/code/html2textile/
#
# Read more at http://jystewart.net/process/2007/11/converting-html-to-textile-with-ruby
#
# Author::    James Stewart  (mailto:james@jystewart.net)
# Copyright:: Copyright (c) 2007 James Stewart
# License::   Distributes under the same terms as Ruby

# This class is an implementation of an SGMLParser designed to convert
# HTML to textile.
# 
# Example usage:
#   parser = HTMLToTextileParser.new
#   parser.feed(input_html)
#   puts parser.to_textile
class HTMLToTextileParser < SGMLParser
  
  attr_accessor :result
  attr_accessor :data_stack
  attr_accessor :a_href
  attr_accessor :list_prefix
  
  @@permitted_tags = []
  @@permitted_attrs = []
  
  def initialize(verbose=true)
    @output = String.new
    self.list_prefix = []
    self.result = []
    self.data_stack = []
    super(verbose)
  end
  
  # Normalise space in the same manner as HTML. Any substring of multiple
  # whitespace characters will be replaced with a single space char.
  def normalise_space(s)
    s.to_s.gsub(/\s+/x, ' ')
  end
  
  def build_styles_ids_and_classes(attributes)
    idclass = ''
    idclass += attributes['class'] if attributes.has_key?('class')
    idclass += "\##{attributes['id']}" if attributes.has_key?('id')
    idclass = "(#{idclass})" if idclass != ''
    
    style = attributes.has_key?('style') ? "{#{attributes['style']}}" : ""
    "#{idclass}#{style}"
  end
  
  def make_block_start_pair(tag, attributes)
    attributes = attrs_to_hash(attributes)
    class_style = build_styles_ids_and_classes(attributes)
    write("\r\n\r\n#{tag}#{class_style}. ")
    start_capture(tag)
  end
  
  def make_block_end_pair
    stop_capture_and_write
  end
  
  def make_quicktag_start_pair(tag, wrapchar, attributes)
    attributes = attrs_to_hash(attributes)
    class_style = build_styles_ids_and_classes(attributes)
    write([" ", "#{wrapchar}#{class_style}"])
    start_capture(tag)
  end

  def make_quicktag_end_pair(wrapchar)
    stop_capture_and_write
    write([wrapchar, " "])
  end
  
  def write(d)
    if self.data_stack.size < 2
      result.push d.to_a
    else
      data_stack[-1].push d.to_a
    end
  end
          
  def start_capture(tag)
    self.data_stack.push([])
  end
  
  def stop_capture_and_write
    self.write(self.data_stack.pop)
  end

  def handle_data(data)
    write(normalise_space(data).strip) unless data.nil? or data == ''
  end

  %w[1 2 3 4 5 6].each do |num|
    define_method "start_h#{num}" do |attributes|
      make_block_start_pair("h#{num}", attributes)
    end
    
    define_method "end_h#{num}" do
      make_block_end_pair
    end
  end

  PAIRS = { 'blockquote' => 'bq', 'p' => 'p' }
  QUICKTAGS = { 'b' => '*', 'strong' => '*', 
    'i' => '_', 'em' => '_', 'cite' => '??', 's' => '-', 
    'sup' => '^', 'sub' => '~', 'code' => '@', 'span' => '%'}
  
  PAIRS.each do |key, value|
    define_method "start_#{key}" do |attributes|
      make_block_start_pair(value, attributes)
    end
    
    define_method "end_#{key}" do
      make_block_end_pair
    end
  end
  
  QUICKTAGS.each do |key, value|
    define_method "start_#{key}" do |attributes|
      make_quicktag_start_pair(key, value, attributes)
    end
    
    define_method "end_#{key}" do
      make_quicktag_end_pair(value)
    end
  end
  
  def start_ol(attrs)
    list_prefix.push '#'
  end

  def end_ol
    list_prefix.pop(list_prefix.rindex('#'))
  end

  def start_ul(attrs)
    list_prefix.push '*'
  end

  def end_ul
    list_prefix.pop(list_prefix.rindex('*'))
  end
  
  def start_li(attrs)
    write("\r\n#{self.list_prefix} ")    
    start_capture("li")
  end

  def end_li
    stop_capture_and_write
  end

  def start_a(attrs)
    attrs = attrs_to_hash(attrs)
    self.a_href = attrs['href']

    if self.a_href:
      write(" \"")
      start_capture("a")
    end
  end

  def end_a
    if self.a_href:
      stop_capture_and_write
      write(["\":", self.a_href, " "])
      self.a_href = false
    end
  end

  def attrs_to_hash(array)
    array.inject({}) { |collection, part| collection[part[0].downcase] = part[1]; collection }
  end

  def start_img(attrs)
    attrs = attrs_to_hash(attrs)
    write([" !", attrs["src"], "! "])
  end
  
  def end_img
  end

  def start_tr(attrs)
  end

  def end_tr
    write("|\r\n")
  end

  def start_td(attrs)
    write("|")
    start_capture("td")
  end

  def end_td
    stop_capture_and_write
    write("|")
  end

  def start_br(attrs)
    write("\r\n")
  end
  
  def unknown_starttag(tag, attrs)
    if @@permitted_tags.include?(tag)
      write(["<", tag])
      attrs.each do |key, value|
        if @@permitted_attributes.include?(key)
          write([" ", key, "=\"", value, "\""])
        end
      end
    end
  end
            
  def unknown_endtag(tag)
    if @@permitted_tags.include?(tag)
      write(["</", tag, ">"])
    end
  end
  
  # Return the textile after processing
  def to_textile
    result.join
  end
  
  ENTITY_MAP = {
    'quot'  => '"',
    'apos' => "'",
    'amp' => '&',
    'lt' => '<',
    'gt' => '>'
  }
  def handle_entityref(tag)
    write(ENTITY_MAP.include?(tag) ? [ENTITY_MAP[tag]] : ['<notextile>&', tag, ';</notextile>'])
  end

  CHAR_MAP = {
    '8217' => "'", 
    '8220' => ' "', # TODO: FIX: HACK, whitespace dissapears somewhere
    '8221' => '" ' # TODO: FIX: HACK, whitespace dissapears somewhere, adding manually
   }
  def handle_charref(tag)
    write(CHAR_MAP.include?(tag) ? [CHAR_MAP[tag]] : ['<notextile>&', tag, ';</notextile>'])
  end
end