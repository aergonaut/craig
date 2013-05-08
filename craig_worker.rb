require "nokogiri"
require "open-uri"
require "sequel"
require "sidekiq"
require "dotenv"

Dotenv.load

Sidekiq.configure_client do |config|
  config.redis = { namespace: "craig", size: 1, url: ENV["REDIS_URL"] }
end

Sidekiq.configure_server do |config|
  config.redis = { namespace: "craig", url: ENV["REDIS_URL"] }
end

class CraigWorker
  include Sidekiq::Worker

  DB = Sequel.connect(ENV["DATABASE_URL"])

  def perform
    craig = Nokogiri::XML(open(ENV["CRAIGSLIST_SEARCH_URL"]))
    craig.remove_namespaces!

    html_body = "New postings:\n\n"

    items = craig.xpath("//item")
    items.each do |item|
      url = item.xpath("link").first.text
      title = item.xpath("title").first.text

      if DB[:listings].where(url: url).empty?
        DB[:listings] << { title: title, url: url }
        html_body << %(<a href="#{url}">#{title}</a>\n\n)
      end
    end

    # TODO: send email
    # File.open("craigs.txt", "w+") do |f|
    #   f << html_body
    # end
  end
end
