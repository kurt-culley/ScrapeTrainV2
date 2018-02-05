require 'HTTParty'
require 'Nokogiri'
require 'open-uri'
require 'byebug'

trap "SIGINT" do
  puts "Exiting..."
  exit 130
end

artist_url = ARGV[0].to_s
artist_page = HTTParty.get(artist_url)
artist_page_parsed = Nokogiri::HTML(artist_page)
artist_name = artist_url.split('/')[-1]
track_list = artist_page_parsed.xpath('//*[@id="content"]/div/div[2]/div/section[1]/div[2]').children
track_ids = []
track_links = []
track_hash_array = []

puts "[BEGIN] Press CTRL+C to quit."
puts "[INFO] Artist: #{artist_name}"

track_list.each do |track|
  track_ids << track.attr('id').gsub("track", "") if !track.attr('id').nil?
end

puts "[INFO] Track count: #{track_ids.count}"
puts "[INFO] Building track hash array, please wait."

track_ids.each do |track_id|
  track_info = HTTParty.get("https://traktrain.com/track/#{track_id}")
  track_hash_array << {'name' => track_info['name'], 'link'=> track_info['link']}
end

puts "[INFO] Creating directory '#{artist_name}' if it does not already exist."
Dir.mkdir("#{artist_name}") unless File.exists?("#{artist_name}")

track_hash_array.each do |track|
  if track["name"].gsub!(/[^0-9a-z ]/i, '')
    puts "[WARN] Track name '#{track["name"]}' contained invalid chars. Filename changed."
  end
  puts "[INFO] Downloading: #{track["name"]}.mp3"
  open("#{artist_name}/#{track["name"]}.mp3", 'wb') do |f|
    f << open("https://d2lvs3zi8kbddv.cloudfront.net/#{track["link"]}",
          "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/42.0",
          "referer" => artist_url).read
  end
  puts "[INFO] Complete: #{track["name"]}.mp3"
end

puts "[DONE]"
