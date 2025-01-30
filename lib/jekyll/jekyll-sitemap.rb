# frozen_string_literal: true

require "fileutils"

module Jekyll
  class JekyllSitemap < Jekyll::Generator
    # Google limits the size of a single sitemap to 50 MB (uncompressed) or 50,000 URLs
    SITEMAP_LIMIT = 30_000

    safe true
    priority :lowest

    # Main plugin action, called by Jekyll-core
    def generate(site)
      @site = site

      if !file_exists?("sitemap.xml")
        sitemaps.each do |sitemap|
          @site.pages << sitemap
          @sitemap = sitemap
        end
      end

      @site.pages << robots unless file_exists?("robots.txt")
    end

    private

    INCLUDED_EXTENSIONS = %w(
      .htm
      .html
      .xhtml
      .pdf
      .xml
    ).freeze

    # Matches all whitespace that follows
    #   1. A '>' followed by a newline or
    #   2. A '}' which closes a Liquid tag
    # We will strip all of this whitespace to minify the template
    MINIFY_REGEX = %r!(?<=>\n|})\s+!.freeze

    # Array of all non-jekyll site files with an HTML extension
    def static_files
      @site.static_files.select { |file| INCLUDED_EXTENSIONS.include? file.extname }
    end

    # Path to sitemap.xml template file
    def source_path(file = "sitemap.xml")
      File.expand_path "../#{file}", __dir__
    end

    # Destination for sitemap.xml file within the site source directory
    def destination_path(file = "sitemap.xml")
      @site.in_dest_dir(file)
    end

    def sitemaps
      all_files = static_files.map(&:to_liquid)

      if all_files.size > SITEMAP_LIMIT
        @sitemap_index = true
        sub_sitemaps = []
        sub_sitemaps_filenames = []

        all_files.each_slice(SITEMAP_LIMIT).with_index do |files, i|
          sub_sitemap_filename = "sitemap_#{i}.xml"
          sub_sitemaps_filenames << sub_sitemap_filename

          site_map = PageWithoutAFile.new(@site, __dir__, "", sub_sitemap_filename)
          site_map.content = File.read(source_path).gsub(MINIFY_REGEX, "")
          site_map.data["layout"] = nil
          site_map.data["static_files"] = files

          sub_sitemaps << site_map
        end

        index = PageWithoutAFile.new(@site, __dir__, "", "sitemap_index.xml")
        index.content = File.read(source_path("sitemap_index.xml")).gsub(MINIFY_REGEX, "")
        index.data["layout"] = nil
        index.data["permalink"] = "/sitemap_index.xml"
        index.data["linked_sitemaps"] = sub_sitemaps_filenames
        index.data["xsl"] = file_exists?("sitemap_index.xsl")

        [sub_sitemaps, index].flatten
      else
        site_map = PageWithoutAFile.new(@site, __dir__, "", "sitemap.xml")
        site_map.content = File.read(source_path).gsub(MINIFY_REGEX, "")
        site_map.data["layout"] = nil
        site_map.data["static_files"] = all_files
        site_map.data["xsl"] = file_exists?("sitemap.xsl")
        
        [site_map]
      end
    end

    def robots
      robots = PageWithoutAFile.new(@site, __dir__, "", "robots.txt")
      robots.content = File.read(source_path("robots.txt"))
      robots.data["layout"] = nil
      robots.data["sitemap"] = @sitemap_index ? "sitemap_index.xml" : "sitemap.xml"
      robots
    end

    # Checks if a file already exists in the site source
    def file_exists?(file_path)
      pages_and_files.any? { |p| p.url == "/#{file_path}" }
    end

    def pages_and_files
      @pages_and_files ||= @site.pages + @site.static_files
    end
  end
end
