require "colorize"
require "open-uri"
require "nokogiri"
require "uri"
require "io/console"

module SeznamSlovnik
  module CLI
    module Commands
      extend Hanami::CLI::Registry

      class Translate < Hanami::CLI::Command
        URL = "https://slovnik.seznam.cz/%s-%s/?q=%s&forceLang=%d".freeze

        argument :query, required: true, desc: "Word to lookup"
        option :source, aliases: %w[s], default: "cz", values: %w[cz en], desc: "Source language"
        option :target, aliases: %w[t], default: "en", values: %w[cz en], desc: "Target language"

        def call(**options)
          source, target = options.values_at(:source, :target)
          force_lang = source == "cz" ? 1 : 0
          query = URI.encode_www_form_component(options.fetch(:query))

          unless [source, target].include?("cz")
            puts "Either source or target must be \"cz\""
            exit 1
          end

          url = URL % [source, target, query, force_lang]
          html = begin
                  open(url).read
                 rescue => e
                   puts "Failed to get html: #{e.message}"

                   exit 1
                 end

          doc = Nokogiri::HTML(html)

          title = doc.css('#results h1').text
          quick_definitions = doc.css('#results #fastMeanings table tr')
            .map(&method(:clean_quick_meaning))
            .reject(&:empty?)

          _lines, columns = IO.console.winsize
          puts
          puts "Results for: #{title.colorize(color: :light_blue, mode: :bold)}"
          puts "=" * (title.length + 13)
          puts
          puts "Quick Definitions"
          puts "=" * 17
          puts
          puts quick_definitions.join("\n" + "-" * columns.to_i + "\n")
        end

        private def clean_quick_meaning(meaning)
          meaning
            .text
            .strip
            .gsub(/\s+/, " ")
            .gsub(/\s,/, ",")
            .colorize(color: :light_blue, mode: :bold)
        end
      end

      register "translate", Translate, aliases: %w[-q --query]
    end
  end
end
