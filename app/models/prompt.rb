require "net/http"

# Base class for prompt types.
class PromptType

  # The number of prompts to keep pooled.
  POOL_SIZE = 100
  
  # The number of attempts to make before giving up.
  MAX_ATTEMPTS = 25
  
  # The number of days to keep prompts around.
  DURATION = 7
  
  attr_reader :name
  
  def initialize(name)
    @name = name
  end

  # Fills the prompt pool.  
  def fill_pool
    number = Prompt.where(prompt_type: @name, game_id: nil).count
    if number < POOL_SIZE
      for index in 0...(POOL_SIZE - number)
        generate
      end
    end
  end

  # Generates a single prompt.
  def generate(game_id = nil)
    nil
  end

end

# Handles Wikipedia articles.
class Wikipedia < PromptType
  
  # The minimum number of views in the last month.
  MIN_VIEWS = 500
  
  def initialize
    super("wikipedia")
  end
  
  def generate(game_id = nil)
    url = "https://en.m.wikipedia.org/wiki/Special:Random"
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      for i in 0...MAX_ATTEMPTS
        response = http.request_get(url)
        if response.is_a? Net::HTTPRedirection
          month = DateTime.now.to_date.prev_month.strftime("%Y%m")
          name = response["location"].rpartition("/")[2]
          view_response = Net::HTTP.get_response("stats.grok.se", "/json/en/#{month}/#{name}")
          if view_response.is_a? Net::HTTPOK
            begin
              total = JSON.parse(view_response.body)["daily_views"].values.reduce(:+)
              if total < MIN_VIEWS
                next
              end
            rescue StandardError => e
              logger.warn e.message
            end
          end
          return Prompt.create(prompt_type: @name, inline_url: response["location"],
            full_url: response["location"].sub("https://en.m", "https://en"), game_id: game_id)
        end
      end
    end
    nil
  end
  
end

# Handles Reddit articles.
class Reddit < PromptType
  
  # The maximum number of comments to include in the prompt.
  MAX_COMMENTS = 25
  
  def initialize
    super("reddit")
  end
  
  def generate(game_id = nil)
    url = "https://www.reddit.com/r/random/random"
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      for i in 0...MAX_ATTEMPTS
        response = http.request_get(url)
        if response.is_a? Net::HTTPRedirection
          response = http.request_get(response["location"])
          if response.is_a? Net::HTTPRedirection
            full_url = response["location"]
            response = http.request_get(full_url + ".rss")
            if response.is_a? Net::HTTPOK
              content = render_rss(response.body)
              if content
                prompt = Prompt.create(prompt_type: @name, content: content,
                  full_url: full_url, game_id: game_id)
                prompt.update(inline_url: "/prompts/#{prompt.id}")
                return prompt
              end
            end
          end
        end
      end
    end
    nil
  end
  
  private
  
    def render_rss(rss)
      rss.encode!("UTF-8", { invalid: :replace, undef: :replace })
      hash = Hash.from_xml(rss)["rss"]["channel"]
      result = "<!DOCTYPE html><html><head>".force_encoding("UTF-8")
      result << "<meta name='viewport' content='initial-scale=1'>"
      result << "<meta charset='UTF-8'>"
      result << "<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css'>"
      result << "<style>h5 { margin: 0px; } img { max-width: 100%; height: auto; }</style>"
      result << "</head>"
      result << "<body><div class='container-fluid'>"
      result << "<h4>#{hash["title"]} (Reddit)"
      result << "<small><br>#{hash["description"]}</small></h4><br>"
      items = hash["item"]
      first_item = items.is_a?(Array) ? items[0] : items
      title = first_item["title"]
      result << "<div class='panel panel-default'>"
      result << "<div class='panel-heading'><h5>#{title.is_a?(Array) ? title[0] : title}"
      time = DateTime.parse(first_item["pubDate"]).in_time_zone
      result << "<small><br>#{time.strftime(Game::TIME_FORMAT)}</small></h5></div>"
      result << "<div class='panel-body'>#{first_item["description"]}"
      if items.is_a?(Array)
        result << "<br><br><div class='panel-group'>"
        for index in 1...[ items.length, MAX_COMMENTS ].min
          item = items[index]
          result << "<div class='panel panel-default'>"
          title = item["title"].partition(" on ")[0]
          result << "<div class='panel-heading'><h5>#{title}"
          time = DateTime.parse(item["date"]).in_time_zone
          result << "<small><br>#{time.strftime(Game::TIME_FORMAT)}</small></h5></div>"
          result << "<div class='panel-body'>#{item["description"]}</div>"
          result << "</div>"
        end
        result << "</div>"
      end
      result << "</div></div></div></body></html>"
      result
    end
    
end

# Handles Splashbase images.
class Splashbase < PromptType
  
  def initialize
    super("splashbase")
  end
  
  def generate(game_id = nil)
    url = "http://www.splashbase.co/api/v1/images/random?images_only=true"
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port) do |http|
      for i in 0...MAX_ATTEMPTS
        response = http.request_get(url)
        if response.is_a? Net::HTTPOK
          data = JSON.parse(response.body)
          return Prompt.create(prompt_type: @name, inline_url: data["url"],
            full_url: data["large_url"], game_id: game_id)
        end
      end
    end
    nil
  end
  
end

# Class for RSS prompt types.
class Rss < PromptType
  
  # The maximum length of a GUID.
  MAX_GUID_LENGTH = 255
  
  def initialize(name, url)
    super(name)
    @url = url
  end
  
  def fill_pool
    uri = URI(@url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => @url.start_with?("https")) do |http|
      for i in 0...MAX_ATTEMPTS
        response = http.request_get(@url)
        if response.is_a? Net::HTTPOK
          response.body.encode!("UTF-8", { invalid: :replace, undef: :replace })
          hash = Hash.from_xml(response.body)["rss"]["channel"]
          title, description = hash["title"], hash["description"]
          items = hash["item"]
          if items.is_a?(Array)
            items.each do |item|
              generate_item(title, description, item)
            end 
          else
            generate_item(title, description, items)
          end
          return
        end
      end
    end
  end

  private
  
    def generate_item(title, description, item)
      guid = item["guid"]
      return if guid.length > MAX_GUID_LENGTH || Prompt.where(prompt_type: @name, guid: guid).count > 0
      
      content = "<!DOCTYPE html><html><head>".force_encoding("UTF-8")
      content << "<meta name='viewport' content='initial-scale=1'>"
      content << "<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css'>"
      content << "<style>h5 { margin: 0px; } img { max-width: 100%; height: auto; }</style>"
      content << "</head>"
      content << "<body><div class='container-fluid'>"
      content << "<h4>#{title}<small><br>#{description}</small></h4><br>"
      content << "<div class='panel panel-default'>"
      content << "<div class='panel-heading'><h5>#{item["title"]}"
      time = DateTime.parse(item["pubDate"]).in_time_zone
      content << "<small><br>#{time.strftime(Game::TIME_FORMAT)}</small></h5></div>"
      content << "<div class='panel-body'>#{item["description"]}</div>"
      content << "</div></div></body></html>"
      
      prompt = Prompt.create(prompt_type: @name, guid: guid, content: content,
        full_url: item["link"], expires: DateTime.now + DURATION)
      prompt.update(inline_url: "/prompts/#{prompt.id}")
    end
end

# Handles Imgur images.
class Imgur < PromptType

  def initialize
    super("imgur")
  end

  def fill_pool
    url = "https://api.imgur.com/3/gallery/user/time"
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      for i in 0...MAX_ATTEMPTS
        response = http.request_get(url, "Authorization" => "Client-ID #{Rails.configuration.x.imgur_client_id}")
        if response.is_a? Net::HTTPOK
          response.body.encode!("UTF-8", { invalid: :replace, undef: :replace })
          data = JSON.parse(response.body)
          if data["success"]
            data["data"].each do |item|
              generate_item(item)
            end
            return
          end
        end
      end
    end
  end

  private
  
    def generate_item(item)
      return if item["is_album"] || item["nsfw"]
      
      guid = "imgur:#{item["id"]}"
      return if Prompt.where(prompt_type: @name, guid: guid).count > 0
      
      content = "<!DOCTYPE html><html><head>".force_encoding("UTF-8")
      content << "<meta name='viewport' content='initial-scale=1'>"
      content << "<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css'>"
      content << "<style>h5 { margin: 0px; } img { max-width: 100%; height: auto; }</style>"
      content << "</head>"
      content << "<body><div class='container-fluid'>"
      content << "<h4>#{item["title"]} (Imgur)<small><br>#{item["description"]}</small></h4><br>"
      content << "<div class='panel panel-default'>"
      content << "<div class='panel-heading'><h5>#{item["account_url"]}"
      time = (DateTime.new(1970) + item["datetime"].second).in_time_zone
      content << "<small><br>#{time.strftime(Game::TIME_FORMAT)}</small></h5></div>"
      content << "<div class='panel-body'><img src='#{item["link"]}'></div>"
      content << "</div></div></body></html>"
      
      prompt = Prompt.create(prompt_type: @name, guid: guid, content: content,
        full_url: "https://imgur.com/gallery/#{item["id"]}", expires: DateTime.now + DURATION)
      prompt.update(inline_url: "/prompts/#{prompt.id}")
    end
    
end

# Handles DeviantArt images.
class DeviantArt < PromptType

  def initialize
    super("deviantart")
  end

  def fill_pool
    base_url = "https://www.deviantart.com/"
    uri = URI(base_url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      for i in 0...MAX_ATTEMPTS
        response = http.request_get(base_url + "oauth2/token?grant_type=client_credentials&client_id=" +
          "#{Rails.configuration.x.deviantart_client_id}&client_secret=#{Rails.configuration.x.deviantart_client_secret}")
        if response.is_a? Net::HTTPOK
          data = JSON.parse(response.body)
          if data["status"] == "success"
            response = http.request_get(base_url +
              "api/v1/oauth2/browse/undiscovered?access_token=#{data["access_token"]}&limit=100")
            if response.is_a? Net::HTTPOK
              response.body.encode!("UTF-8", { invalid: :replace, undef: :replace })
              data = JSON.parse(response.body)
              data["results"].each do |item|
                generate_item(item)
              end
              return
            end
          end
        end
      end
    end
  end

  private
  
    def generate_item(item)
      return if item["is_mature"] || !item["content"]
      
      guid = "deviantart:#{item["deviationid"]}"
      return if Prompt.where(prompt_type: @name, guid: guid).count > 0
      
      content = "<!DOCTYPE html><html><head>".force_encoding("UTF-8")
      content << "<meta name='viewport' content='initial-scale=1'>"
      content << "<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css'>"
      content << "<style>h5 { margin: 0px; } img { max-width: 100%; height: auto; }</style>"
      content << "</head>"
      content << "<body><div class='container-fluid'>"
      content << "<h4>#{item["title"]} (DeviantArt)<small><br>#{item["category"]}</small></h4><br>"
      content << "<div class='panel panel-default'>"
      content << "<div class='panel-heading'><h5>#{item["author"]["username"]}"
      time = (DateTime.new(1970) + item["published_time"].second).in_time_zone
      content << "<small><br>#{time.strftime(Game::TIME_FORMAT)}</small></h5></div>"
      content << "<div class='panel-body'><img src='#{item["content"]["src"]}'></div>"
      content << "</div></div></body></html>"
      
      prompt = Prompt.create(prompt_type: @name, guid: guid, content: content,
        full_url: "#{item["url"]}", expires: DateTime.now + DURATION)
      prompt.update(inline_url: "/prompts/#{prompt.id}")
    end
    
end

# Handles Flickr images.
class Flickr < PromptType

  def initialize
    super("flickr")
  end

  def fill_pool
    url = "https://api.flickr.com/services/rest/?method=flickr.photos.getRecent&" +
      "extras=description%2Cdate_upload%2Cowner_name%2Curl_c&" +
      "api_key=#{Rails.configuration.x.flickr_key}&format=json&nojsoncallback=1&"
    uri = URI(url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => true) do |http|
      for i in 0...MAX_ATTEMPTS
        response = http.request_get(url)
        if response.is_a? Net::HTTPOK
          response.body.encode!("UTF-8", { invalid: :replace, undef: :replace })
          data = JSON.parse(response.body)
          if data["stat"] == "ok"
            data["photos"]["photo"].each do |item|
              generate_item(item)
            end
            return
          end
        end
      end
    end
  end

  private
  
    def generate_item(item)
      return unless item["url_c"] && item["ispublic"] == 1
    
      guid = "flickr:#{item["id"]}"
      return if Prompt.where(prompt_type: @name, guid: guid).count > 0
      
      content = "<!DOCTYPE html><html><head>".force_encoding("UTF-8")
      content << "<meta name='viewport' content='initial-scale=1'>"
      content << "<link rel='stylesheet' href='//maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css'>"
      content << "<style>h5 { margin: 0px; } img { max-width: 100%; height: auto; }</style>"
      content << "</head>"
      content << "<body><div class='container-fluid'>"
      content << "<h4>#{item["title"]} (Flickr)<small><br>#{item["description"]["_content"]}</small></h4><br>"
      content << "<div class='panel panel-default'>"
      content << "<div class='panel-heading'><h5>#{item["ownername"]}"
      time = (DateTime.new(1970) + item["dateupload"].to_i.second).in_time_zone
      content << "<small><br>#{time.strftime(Game::TIME_FORMAT)}</small></h5></div>"
      content << "<div class='panel-body'><img src='#{item["url_c"]}'></div>"
      content << "</div></div></body></html>"
      
      content = content.each_char.select{|c| c.bytes.count < 4 }.join('')
      
      prompt = Prompt.create(prompt_type: @name, guid: guid, content: content,
        full_url: "https://www.flickr.com/photos/#{item["owner"]}/#{item["id"]}", expires: DateTime.now + DURATION)
      prompt.update(inline_url: "/prompts/#{prompt.id}")
    end
    
end

class Prompt < ActiveRecord::Base
  
  # The available prompt types.
  TYPES = [ Wikipedia.new, Reddit.new, Imgur.new, DeviantArt.new, Flickr.new,
    Rss.new("mashable", "http://mashable.com/rss/"),
    Rss.new("boingboing", "http://boingboing.net/feed"),
    Rss.new("techcrunch", "http://feeds.feedburner.com/techcrunch"),
    Rss.new("500px", "https://500px.com/upcoming.rss") ]
  
  # Fills the pools for the prompt types.
  def self.fill_pools
    TYPES.each do |type|
      type.fill_pool
    end
  end
  
  # Generates a prompt of the named type for the given game.
  def self.generate(type_name, game_id)
    TYPES.each do |type|
      if type.name == type_name
        return type.generate(game_id)
      end
    end
  end
  
  belongs_to :game
  
  # Checks whether the prompt's url is still valid.
  def url_valid?
    uri = URI(full_url)
    Net::HTTP.start(uri.host, uri.port, :use_ssl => full_url.start_with?("https")) do |http|
      response = http.request_get(full_url)
      return response.is_a?(Net::HTTPOK) || response.is_a?(Net::HTTPRedirection)
    end
  end
  
end
