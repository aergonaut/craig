require "bundler"
Bundler.require(:default, ENV["CRAIG_ENV"] || :development)
require "uri"

unless ENV["CRAIG_ENV"]
  ENV["CRAIG_ENV"] = "development"
end

Dotenv.load if ENV["CRAIG_ENV"] == "development"

Sidekiq.configure_client do |config|
  config.redis = { namespace: "craig", size: 1, url: ENV["REDIS_URL"] }
end

Sidekiq.configure_server do |config|
  config.redis = { namespace: "craig", url: ENV["REDIS_URL"] }
end

if ENV["CRAIG_ENV"] == "production"
  Pony.options = {
    from: "craig@aergonaut.com",
    to: ENV["PONY_RECIPIENTS"],
    subject: "craig - New listings found!",
    via: :smtp,
    via_options: {
      address: "smtp.sendgrid.net",
      port: "587",
      domain: "heroku.com",
      user_name: ENV["SENDGRID_USERNAME"],
      password: ENV["SENDGRID_PASSWORD"],
      authentication: :plain,
      enable_starttls_auto: true
    }
  }
else # development
  Pony.options = {
    from: "craig@aergonaut.com",
    to: ENV["PONY_RECIPIENTS"],
    subject: "craig - New listings found!",
    via: LetterOpener::DeliveryMethod,
    via_options: {
      location: File.expand_path("./tmp/letter_opener")
    }
  }
end

class CraigWorker
  include Sidekiq::Worker

  DB = Sequel.connect(ENV["DATABASE_URL"])

  def uri
    @uri ||= URI.parse(ENV["CRAIGSLIST_SEARCH_URL"])
  end

  def conn
    @conn ||= Faraday.new url: "http://#{uri.host}" do |faraday|
      faraday.request :url_encoded
      faraday.response :logger
      faraday.adapter :net_http
    end
  end

  def perform
    response = conn.get "#{uri.path}?#{uri.query}"
    rss = response.body

    craig = Nokogiri::XML(rss)
    craig.remove_namespaces!

    listings = []

    items = craig.xpath("//item")
    items.each do |item|
      url = item.xpath("link").first.text
      title = item.xpath("title").first.text

      if DB[:listings].where(url: url).empty?
        DB[:listings] << { title: title, url: url }
        listings << %(<a href="#{url}">#{title}</a>)
      end
    end

    unless listings.empty?
      html_body = listings.unshift("New listings:").join("<br /><br />")

      # TODO: send email
      Pony.mail(html_body: html_body)
    end
  end
end
