# Kurt Culley 2018
require 'HTTParty'
require 'Nokogiri'
require 'open-uri'
require 'mp3info'
require 'byebug'

trap "SIGINT" do
  puts "Exiting..."
  exit 130
end

user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/42.0"
artist_url = ARGV[0].to_s
artist_page = HTTParty.get(artist_url)
artist_page_parsed = Nokogiri::HTML(artist_page)
artist_name = artist_url.split('/')[-1]
track_list = artist_page_parsed.xpath('//*[@id="tracks-container"]').children
track_ids = []
track_links = []
track_hash_array = []

puts "[BEGIN] Press CTRL+C to quit."
puts "[INFO] Artist: #{artist_name}"

# Iterate through the scraped track_list, checking to see if it contains the
# id attribute. If so, we remove 'track' from the returned string, leaving us
# with just the track id e.g. 'track12345' => '12345', which is then inserted
# into the track_ids array.
track_list.each do |track|
  track_ids << track.attr('id').gsub("track", "") if !track.attr('id').nil?
end

puts "[INFO] Track count: #{track_ids.count}"
puts "[INFO] Building track hash array, please wait."

# Iterate through track_ids, calling the endpoint for the track, which returns
# JSON containing all the information related to that track.
# This information is then used to build an array of track hashes, each
# containing the title, artist, album, track number, mp3 url and
# album artwork url.

track_ids.each_with_index do |track_id, index|
  track_info = HTTParty.get("https://traktrain.com/track/#{track_id}")
  tracknum = index + 1
  track_hash_array << {
    'title' => "#{tracknum}. " + track_info['name'].gsub(/[^0-9a-z ]/i, ''), # Sanitize for filename
    'artist' => artist_name,
    'album' => 'Traktrain',
    'tracknum' => tracknum,
    'link'=> track_info['link'],
    'image' => track_info['image']}
end

puts "[INFO] Creating directory '#{artist_name}' if it does not already exist."
Dir.mkdir("#{artist_name}") unless File.exists?("#{artist_name}")

# Iterate through track_hash_array, for each track we download the mp3 and
# save under artist_name/track_title.mp3.
# We then insert the ID3 tags for the MP3, first downloading and inserting
# the album artwork, then we insert the title, artist, album and track number.
track_hash_array.each do |track|
  open("#{artist_name}/#{track["title"]}.mp3", 'wb') do |f|
    begin
      puts "[INFO] Downloading: #{track["title"]}.mp3"
      # Download MP3
      f << open("https://d2lvs3zi8kbddv.cloudfront.net/#{track["link"]}",
        "User-Agent" => user_agent,
        "referer" => artist_url).read
        # Referer must be included to bypass the Traktrain 'ban' page.
        puts "[INFO] Complete: #{track["title"]}.mp3"
      rescue OpenURI::HTTPError => exception
        puts "[ERROR] '#{track["title"]}' skipped. - #{exception} "
      end
    end
    # Insert ID3 tags
    Mp3Info.open("#{artist_name}/#{track["title"]}.mp3") do |mp3|
        begin
          artwork = open("https://d369yr65ludl8k.cloudfront.net/#{track["image"]}",
            "User-Agent" => user_agent,
            "referer" => artist_url).read
        rescue OpenURI::HTTPError => exception
          puts "[ERROR] '#{track["title"]}' skipped. - #{exception} "
        end
        mp3.tag2.add_picture(artwork)
        mp3.tag.title = track["title"]
        mp3.tag.artist = artist_name
        mp3.tag.album = track["album"]
        mp3.tag.tracknum = track["tracknum"]
    end
end

puts "[DONE]"
