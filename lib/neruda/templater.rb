# frozen_string_literal: true

require 'nokogiri'
require 'digest/md5'
require 'neruda/org_file'

module Neruda
  # Insert custom part inside generated HTML files.
  class Templater
    def initialize(source, dom, opts = {})
      @dom = dom
      @position = opts['type'] || 'after'
      @content = opts['content']
      @element = @dom.css(opts['selector'])
      digest = Digest::MD5.hexdigest(@content)
      @check_line = " Neruda Template: #{digest} "
      @org_file = Neruda::OrgFile.new(source)
    end

    def apply
      flag_head
      content = @org_file.format(@content)
      @element.each do |e|
        insert_new_node_at e, content
      end
    end

    def in_head?
      @dom.xpath('//head').children.to_a.filter(&:comment?).each do |c|
        return true if c.text == @check_line
      end
      false
    end

    class << self
      def customize_output(file_name)
        templates = Neruda::Config.settings['templates']
        return if templates.nil? || templates.empty?
        dom = open_dom(file_name)
        templates.each do |t|
          next unless t.has_key?('selector') && t.has_key?('content')
          next if t.has_key?('path') && !check_path(file_name, t['path'])
          source = Neruda::OrgFile.source_for_target(file_name)
          tpl = Neruda::Templater.new(source, dom, t)
          next if tpl.in_head?
          tpl.apply
        end
        write_dom(file_name, dom)
      end

      private

      def open_dom(file_name)
        file = File.new file_name, 'r'
        dom = Nokogiri::HTML file
        file.close
        dom
      end

      def write_dom(file_name, dom)
        file = File.new file_name, 'w'
        dom.write_to file
        file.close
      end

      def check_path(file_name, pathes)
        pub_folder = Neruda::Config.settings['public_folder']
        if pathes.is_a?(Array)
          pathes.each do |tp|
            return true if File.fnmatch?("#{pub_folder}#{tp}",
                                         file_name, File::FNM_DOTMATCH)
          end
          return false
        end
        File.fnmatch?("#{pub_folder}#{pathes}",
                      file_name, File::FNM_DOTMATCH)
      end
    end

    private

    def flag_head
      @dom.xpath('//head').first.prepend_child("<!--#{@check_line}-->\n")
    end

    def insert_new_node_at(elem, content)
      if @position == 'before'
        elem.add_previous_sibling content
      elsif @position == 'replace'
        elem.replace content
      else
        elem.add_next_sibling content
      end
    end
  end
end