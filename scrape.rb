require "watir"
require "csv"
require "nokogiri"
require "open-uri"
require "whois"
require "phony"
require "domainatrix"
require "awesome_print"
require "pry"

browser = Watir::Browser.new :chrome 

countries = [{:country => "US", :pages => 303,  :cc => '1'},
             {:country => "CA", :pages => 35,   :cc => '1'}, 
             {:country => "AU", :pages => 45,   :cc => '61'}, 
             {:country => "GB", :pages => 146,  :cc => '41'}]
# browser.goto "http://shops.oscommerce.com/directory?country=US"
list = []

# /\b[\s()\d-]{6,}\d\b/

phone_regex = /\b(?:\+?|\b)[0-9]{10}\b/
email_regex = /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}\b/

# A store: 

# X Url:
# Email:
# X Type:
# Phone:
# X Country

# puts browser.table(:index, 4).exists?
countries.each do |country|
  country[:pages].times do |page|
    browser.goto "http://shops.oscommerce.com/directory?page=#{page + 1}&country=#{country[:country]}"
    table = browser.table(:index, 2)

    table.uls.each do |ul|
      ul.lis.each do |li|
        name = li.a.text
        li.a.href

        category = li.text
        category.slice! "#{li.a.text}\n"

        puts category
        
        html = Nokogiri::HTML(open(li.a.href))
        link = html.xpath("//frame").first.attributes["src"].value
        link.slice! "live_shops_frameset_header.php?url="
        puts link
        
        domain = Domainatrix.parse(link)
        domain = "#{domain.domain}.#{domain.public_suffix}"

        whois = Whois.whois(domain)
        contact = whois.parser
        next if contact.available?
        # ap contact = contact.registrant_contact.first

        # email = contact.email if contact.respond_to? "email"

        begin
          owner_email = contact.phone
          owner_phone = contact.phone
        rescue 
          owner_email = ""
          owner_phone = ""
        end

        begin
          html = Nokogiri::HTML(open(link))
        rescue
          site = {:Name => name }
          list << site
          next
        end

        # binding.pry
        contact_page = html.at('a:contains("ontact")').attributes["href"].value

        begin
          html = Nokogiri::HTML(open(contact_page))          
        rescue 
          site = {:Name => name }
          list << site
          next
        end

        phones = html.to_s.scan(phone_regex)
        puts phones
        emails = html.to_s.scan(email_regex)
        puts emails

        # How do we extract?

        phone = phones.select { |p| Phony.plausible? p }
        email = emails.first

        site = {:Name        => name, 
                :Link        => link, 
                :Type        => category,
                :Owner_Email => owner_email,
                :Owner_Phone => owner_phone,
                :Country     => country[:country],
                :Email       => email,
                :Phone       => phone }

        list << site
      end
    end
  end
end

# ["Name", "Link", "Type", "Owner_Email", "Owner_Phone", "Country", "Email", "Phone"]

browser.quit

puts list 

CSV.open("data.csv", "wb") do |csv|
  csv << list.first.keys.collect { |k| k.gsub("_", " ")  }
  list.each do |item|
    csv << item.values
  end
end

