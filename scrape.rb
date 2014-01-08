require "watir"
require "csv"
require "nokogiri"
require "open-uri"
require "whois"
require "phony"
require "domainatrix"
require "awesome_print"
require "pry"


countries = [{:country => "US", :pages => 303,  :cc => '1'},
             {:country => "CA", :pages => 35,   :cc => '1'}, 
             {:country => "AU", :pages => 45,   :cc => '61'}, 
             {:country => "GB", :pages => 146,  :cc => '41'}]
list = []

# /\b[\s()\d-]{6,}\d\b/

phone_regex = /\b(?:\+?|\b)[0-9]{10}\b/
email_regex = /[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,4}/i

# A store: 

# X Url:
# Email:
# X Type:
# Phone:
# X Country


countries.each do |country|
  country[:pages].times do |page|
    shops = Nokogiri::HTML(open("http://shops.oscommerce.com/directory?page=#{page + 1}&country=#{country[:country]}"))
    lis = shops.css("table + table ul li a:first-child")
    lis.each do |li|
      name = li.children.text 
      iframe_url = li.attributes['href'].value

      category = li.css("~ small").text
      puts category
      
      html = Nokogiri::HTML(open(iframe_url))
      link = html.xpath("//frame").first.attributes["src"].value
      link.slice! "live_shops_frameset_header.php?url="
      puts link
      
      domain = Domainatrix.parse(link)
      domain = "#{domain.domain}.#{domain.public_suffix}"

      # ap contact = contact.registrant_contact.first

      # email = contact.email if contact.respond_to? "email"

      begin
        whois = Whois.whois(domain)
        contact = whois.parser
        owner_email = contact.phone
        owner_phone = contact.phone
      rescue 
        owner_email = ""
        owner_phone = ""
        puts "no domain owner's phone/email found"
      end

      begin
        html = Nokogiri::HTML(open(link))
      rescue
        puts "link did not work"
        site = {:Name => name, :Link => "Possibly defunct"}
        list << site
        next
      end

      # binding.pry

      begin
        contact_page = html.at('a:contains("ontact")').attributes["href"].value
        html = Nokogiri::HTML(open(contact_page))          
        phones = html.to_s.scan(phone_regex)
        puts phones
        emails = html.to_s.scan(email_regex)
        puts emails
      rescue 
        puts "no emails/phones found"
        emails = []
        phones = []
      end

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

# ["Name", "Link", "Type", "Owner_Email", "Owner_Phone", "Country", "Email", "Phone"]


puts list 

CSV.open("data.csv", "wb") do |csv|
  csv << list.first.keys.collect { |k| k.gsub("_", " ")  }
  list.each do |item|
    csv << item.values
  end
end