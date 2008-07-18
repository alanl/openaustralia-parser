#!/usr/bin/env ruby

$:.unshift "#{File.dirname(__FILE__)}/lib"

require 'mechanize_proxy'
require 'name'
require 'people'
require 'configuration'
require 'hpricot'
require 'open-uri'


conf = Configuration.new

agent = MechanizeProxy.new
agent.cache_subdirectory = "parse-wikipedia"

puts "Reading member data..."
people = People.read_members_csv("data/people.csv", "data/members.csv")

puts "Wikipedia links for MPs ..."

doc = Hpricot(open("http://en.wikipedia.org/wiki/Members_of_the_Australian_House_of_Representatives%2C_2007-2010"))
doc_sen = Hpricot(open("http://en.wikipedia.org/wiki/Members_of_the_Australian_Senate%2C_2005-2008"))


xml_mps = File.open("#{conf.members_xml_path}/wikipedia-mps.xml", 'w')
xml_sen = File.open("#{conf.members_xml_path}/wikipedia-senators.xml", 'w')
x = Builder::XmlMarkup.new(:target => xml_mps, :indent => 1)
x.instruct!
x.publicwhip do
  # House of Representatives
 doc.search("//table[@class='wikitable sortable']").search("td").each do |cell|
   #puts "== Found a link =="
   cell.search("a").each do |link|

	 nametext = link.inner_html	
	 url = link.get_attribute("href")
     #puts innerhtml
	 if nametext =~ /\d{4}/ or nametext =~ /.*(Australia|Party|National|Queensland|Liberal|Tasmania|First|Wales|Victoria|Independent)/ or nametext.length < 6 or
	   url =~ /^\/wiki\/Division_of.*/
	  # do nothing
	 else
	  
	  person = people.find_person_by_name_current_on_date(Name.title_first_last(nametext), Date.today)
      if person
		wiki_url = "http://en.wikipedia.org#{url}"
        #puts wiki_url
		params = {:id => person.id, :wikipedia_url => wiki_url}
	 
	    x.personinfo(params)
	  else
		puts "WARNING: Could not find MP with name #{nametext}" 
	  end 
   end
 end
 end
end

puts "Wikipedia links for senators ..."
xsen = Builder::XmlMarkup.new(:target => xml_sen, :indent => 1)
xsen.instruct!
xsen.publicwhip do
  # Senate
 doc_sen.search("//table[@class='wikitable sortable']").search("td").each do |cell|
   #puts "== Found a link =="
   cell.search("a").each do |link|

	 nametext = link.inner_html	
     #puts innerhtml
	 if nametext =~ /\d{4}/ or nametext =~ /.*(Australia|Party|National|Queensland|Liberal|Tasmania|First|Wales|Victoria|Territory)/ or nametext.length < 6
	  # do nothing
	 else
	  
	  person = people.find_senator_by_name(Name.title_first_last(nametext))
      if person
		wiki_url = "http://en.wikipedia.org#{link.get_attribute("href")}"
        #puts wiki_url
		params = {:id => person.id, :wikipedia_url => wiki_url}
	 
	    xsen.personinfo(params)
	  else
		puts "WARNING: Could not find senator with name #{nametext}" 
	  end 
   end
 end
 end
end
xml_mps.close
xml_sen.close
