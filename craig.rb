require "nokogiri"
require "open-uri"
require "sequel"

DB = Sequel.connect(ENV["DATABASE_URL"])

# get the rss feed
craig = Nokogiri::XML(open(ENV["CRAIGSLIST_SEARCH_URL"]))

# obliterate namespaces becuase xpath with namespaces is hard
craig.remove_namespaces!

html_body = "New postings:\n\n"

items = craig.xpath("//item").map
items.each do |item|
  url = item.xpath("link").first.text
  title = item.xpath("title").first.text

  # check that we haven't seen this posting url before
  if DB[:items].where(url: url).empty?
    # stick it in the database
    DB[:items] << { url: url }

    # add it to the body
    html_body << %(<a href="#{url}">#{title}</a>\n\n)
  end
end

# TODO: send email
