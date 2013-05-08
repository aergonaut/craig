require "nokogiri"
require "open-uri"
require "sequel"
require "sidekiq"

class CraigWoker
  include SideKiq::Worker

  def perform
    DB = Sequel.connect(ENV["DATABASE_URL"])

    craig = Nokogiri::XML(open(ENV["CRAIGSLIST_SEARCH_URL"]))
    craig.remove_namespaces!

    html_body = "New postings:\n\n"

    items = craig.xpath("//item")
    items.each do |item|
      url = item.xpath("link").first.text
      title = item.xpath("title").first.text

      if DB[:listings].where(url: url).empty?
        DB[:listings] << { title: title, url: url }
        html_body << %(<a href="#{url}">#{title}</a>)
      end
    end

    # TODO: send email
  end
end
