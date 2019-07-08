# frozen_string_literal: true

require 'cgi'
require 'neruda/config'

module Neruda
  # Embeds Atom feeds sepecific methods
  module IndexAtomGenerator
    def to_atom(index_name = 'index')
      content = [atom_header(index_name)]
      @index[index_name][0...10].each do |article|
        content << atom_entry(article)
      end
      content.join("\n") + '</feed>'
    end

    def write_atom(index_name)
      slug = @slugs[index_name]
      FileUtils.mkdir_p "#{@pubdir}/feeds"
      atomdest = "#{@pubdir}/feeds/#{slug}.xml"
      IO.write(atomdest, to_atom(index_name))
      atomdest
    end

    private

    # Render the Atom feed header.
    #
    # @param title [String] the title of the current atom feed
    # @return [String] the Atom header as a String
    def atom_header(title)
      domain = Neruda::Config.settings['domain']
      upddate = @date.rfc3339
      slug = Neruda::OrgFile.slug(title)
      tagurl = "#{domain}/tags/#{slug}.html"
      if title == 'index'
        if Neruda::Config.settings['title']
          title = Neruda::Config.settings['title']
        end
        tagurl = "#{domain}/#{@blog_path}"
      end
      title_esc = CGI.escapeHTML(title)
      <<~ENDATOM
        <?xml version="1.0" encoding="utf-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom"
              xmlns:dc="http://purl.org/dc/elements/1.1/"
              xmlns:wfw="http://wellformedweb.org/CommentAPI/"
              xml:lang="#{Neruda::Config.settings['lang']}">

        <title>#{title_esc}</title>
        <link href="#{domain}/feeds/#{slug}.xml" rel="self" type="application/atom+xml"/>
        <link href="#{tagurl}" rel="alternate" type="text/html" title="#{title_esc}"/>
        <updated>#{upddate}</updated>
        <author><name>#{Neruda::Config.settings['author'] || ''}</name></author>
        <id>urn:md5:#{Digest::MD5.hexdigest(domain)}</id>
        <generator uri="https://fossil.deparis.io/neruda">Neruda</generator>
      ENDATOM
    end

    # Render an Atom feed entry.
    #
    # @param article [Neruda::OrgFile] the related org document for this
    #   entry
    # @return [String] the Atom entry as a String
    def atom_entry(article)
      keywords = article.keywords.map do |k|
        "<dc:subject>#{CGI.escapeHTML(k)}</dc:subject>"
      end.join
      keywords += "\n  " if keywords != ''
      title_esc = CGI.escapeHTML(article.title)
      <<~ENDENTRY
        <entry>
          <title>#{title_esc}</title>
          <link href="#{article.url}" rel="alternate" type="text/html"
                title="#{title_esc}"/>
          <id>urn:md5:#{Digest::MD5.hexdigest(article.timekey)}</id>
          <published>#{article.datestring(:rfc3339)}</published>
          <author><name>#{CGI.escapeHTML(article.author)}</name></author>
          #{keywords}<content type="html">#{CGI.escapeHTML(article.excerpt)}</content>
        </entry>
      ENDENTRY
    end
  end
end