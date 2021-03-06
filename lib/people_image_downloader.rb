require 'rubygems'
require 'RMagick'
require 'mechanize_proxy'

require 'configuration'

class PeopleImageDownloader
  @@SMALL_THUMBNAIL_WIDTH = 44
  @@SMALL_THUMBNAIL_HEIGHT = 59

  def initialize
    # Required to workaround long viewstates generated by .NET (whatever that means)
    # See http://code.whytheluckystiff.net/hpricot/ticket/13
    Hpricot.buffer_size = 262144

    @conf = Configuration.new
    @agent = MechanizeProxy.new
    @agent.cache_subdirectory = "member_images"
  end

  def download(people, small_image_dir, large_image_dir)
    each_person_bio_page do |page|
      name, birthday, image = extract_name_and_birthday_and_image_from_page(page)

      if name
        # Small HACK - removing title of name
        name = Name.new(:first => name.first, :middle => name.middle, :last => name.last, :post_title => name.post_title)
        person = people.find_person_by_name_and_birthday(name, birthday)
        if person
          image.resize_to_fit(@@SMALL_THUMBNAIL_WIDTH, @@SMALL_THUMBNAIL_HEIGHT).write(small_image_dir + "/#{person.person_count}.jpg")
          image.resize_to_fit(@@SMALL_THUMBNAIL_WIDTH * 2, @@SMALL_THUMBNAIL_HEIGHT * 2).write(large_image_dir + "/#{person.person_count}.jpg")
        else
          puts "WARNING: Skipping photo for #{name.full_name} because they don't exist in the list of people"
        end
      end
    end
  end

  def each_person_bio_page
    # Iterate over current members of house
    @agent.get(@conf.current_house_members_url).links[29..-4].each do |link|
      @agent.transact {yield @agent.click(link)}
    end
    # Iterate over current members of senate
    @agent.get(@conf.current_senate_members_url).links[29..-4].each do |link|
      @agent.transact {yield @agent.click(link)}
    end
    # Iterate over former members of house and senate
    @agent.get(@conf.former_members_house_and_senate_url).links[29..-4].each do |link|
      @agent.transact {yield @agent.click(link)}
    end
  end

  def extract_name_and_birthday_and_image_from_page(page)
    begin
      name = Name.last_title_first(page.search("#txtTitle").inner_text.to_s[14..-1])
    rescue
      #Mr X strikes again! http://parlinfoweb.aph.gov.au/piweb/view_document.aspx?ID=15517&TABLE=BIOGS
      puts "WARNING: Skipping photo download; '#{page.search("#txtTitle").inner_text.to_s[14..-1]}' is an invalid name."
      return
    end

    #Try to scrape the member's birthday.
    #Here's an example of what we are looking for:
    #<H2>Personal</H2>
    #<P>Born 9.1.42
    # or
    #<H2>Personal</H2><P>
    #<P>Born 4.11.1957

    born = page.parser.to_s.match("Born\\s\\d\\d?\\.\\d\\d?\\.\\d\\d(\\d\\d)?")
    if(born and born.to_s.size > 0)
      born_text = born.to_s[5..-1]
      born_text = born_text.insert(-3, "19") if born_text.match("\\.\\d\\d$") # change 9.1.42 to 9.1.1942
      birthday = Date.strptime(born_text, "%d.%m.%Y")
    else
      birthday = nil
    end

    #note: could use the following to output ALL birthdays for easy import into people.csv
    #puts "#{name.informal_name} #{birthday}"

    content = page.search('div#contentstart')
    img_tag = content.search("img").first
    if img_tag
      relative_image_url = img_tag.attributes['src']
      if relative_image_url != "images/top_btn.gif"
        begin
          res = @agent.get(relative_image_url)
          return name, birthday, Magick::Image.from_blob(res.body)[0]
        rescue RuntimeError, Magick::ImageMagickError, WWW::Mechanize::ResponseCodeError
          puts "WARNING: Could not load image for #{name.informal_name} at #{relative_image_url}"
        end
      end
    end
  end
end