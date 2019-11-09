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
        ABBREVIATION = /\b(sb|sth)\b/

        argument :query, required: true, desc: "Word to lookup"
        option :color, type: :boolean, default: true, desc: "Colorize output"
        option :source, aliases: %w[s], default: "cz", values: %w[cz en], desc: "Source language"
        option :target, aliases: %w[t], default: "en", values: %w[cz en], desc: "Target language"

        def call(**options)
          source, target, color = options.values_at(:source, :target, :color)
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

          title = doc.css('h1').text
          parts = doc
            .css('.TranslatePage-results .Box--partOfSpeech')
            .map(&method(:build_part_of_speech))

          _, columns = IO.console.winsize
          out = <<~OUT

            Results for: #{title.colorize(color: :light_blue, mode: :bold)}
            #{"=" * (title.length + 13)}

            Definitions
            ===========

          OUT

          parts.each do |part|
            out << part[:name]
            out << "\n"
            out << "-" * part[:name].length
            out << "\n"
            part[:definitions].each_with_index do |definition, i|
              out << " #{i + 1})"
              needs_padding = false
              definition[:lines].each do |line|
                out << " " * part[:definition_pad] if needs_padding
                out << "  * #{line}\n"
                needs_padding = true
              end
            end
            out << "\n"
          end
          out << "\n"
          out << "-" * columns.to_i

          puts(color ? out : out.uncolorize)
        end

        private def build_part_of_speech(part)
          pos = {}
          pos[:name] = part.at_css('.Box-header-title').text
          pos[:definitions] = part.css('li').map(&method(:build_definition))
          pos[:definition_pad] = pos[:definitions].length.to_s.length + 2 # " 1)"
          pos
        end

        private def build_definition(definition)
          df = {}
          df[:lines] = definition.css('.Box-content-line').map(&method(:clean_line))
          df
        end

        private def clean_line(line)
          line.children.map do |part|
            next '->' if part['class'].to_s == "Box-content-pointer"
            part.text
          end.map(&:strip).reject(&:empty?).join(' ')
        end
      end

      register "translate", Translate, aliases: %w[-q --query]
    end
  end
end
