# frozen_string_literal: true

# Client for interacting with Audible's unofficial API to fetch wishlist items.
# Authentication requires an access token obtained from an Audible session.
# See: https://github.com/mkb79/Audible for authentication details
class AudibleClient
  class Error < StandardError; end
  class ConnectionError < Error; end
  class AuthenticationError < Error; end
  class NotConfiguredError < Error; end

  # Audible API base URLs by marketplace country code
  COUNTRY_URLS = {
    "us" => "https://api.audible.com",
    "uk" => "https://api.audible.co.uk",
    "de" => "https://api.audible.de",
    "fr" => "https://api.audible.fr",
    "ca" => "https://api.audible.ca",
    "au" => "https://api.audible.com.au",
    "in" => "https://api.audible.in",
    "jp" => "https://api.audible.co.jp",
    "it" => "https://api.audible.it",
    "es" => "https://api.audible.es"
  }.freeze

  WishlistItem = Data.define(:asin, :title, :authors, :narrators) do
    def author
      authors.join(", ")
    end

    def narrator
      narrators.join(", ")
    end
  end

  class << self
    # GET /1.0/wishlist - Fetch all wishlist items, handling pagination
    def wishlist
      ensure_configured!

      items = []
      page = 0

      loop do
        response = request do
          connection.get("/1.0/wishlist", {
            num_results: 50,
            page: page,
            response_groups: "product_attrs,contributors"
          })
        end

        page_items = handle_response(response) do |data|
          (data["products"] || []).map { |product| parse_wishlist_item(product) }
        end

        items.concat(page_items)
        break if page_items.size < 50

        page += 1
      end

      items
    end

    def configured?
      SettingsService.audible_configured?
    end

    def test_connection
      ensure_configured!
      wishlist.is_a?(Array)
    rescue Error
      false
    end

    def reset_connection!
      @connection = nil
    end

    private

    def ensure_configured!
      raise NotConfiguredError, "Audible is not configured" unless configured?
    end

    def request
      yield
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::SSLError => e
      raise ConnectionError, "Failed to connect to Audible: #{e.message}"
    end

    def connection
      @connection ||= Faraday.new(url: base_url) do |f|
        f.request :json
        f.response :json, parser_options: { symbolize_names: false }
        f.adapter Faraday.default_adapter
        f.headers["Authorization"] = "Bearer #{access_token}"
        f.options.timeout = 30
        f.options.open_timeout = 10
      end
    end

    def base_url
      country = SettingsService.get(:audible_country_code, default: "us").to_s.downcase
      COUNTRY_URLS.fetch(country, COUNTRY_URLS["us"])
    end

    def access_token
      SettingsService.get(:audible_access_token)
    end

    def handle_response(response)
      case response.status
      when 200, 201
        yield response.body
      when 401, 403
        raise AuthenticationError, "Invalid Audible access token"
      when 404
        raise Error, "Audible resource not found"
      else
        raise Error, "Audible API error: #{response.status}"
      end
    end

    def parse_wishlist_item(data)
      authors = (data["authors"] || []).map { |a| a["name"] }.compact
      narrators = (data["narrators"] || []).map { |n| n["name"] }.compact

      # The Audible API uses "title" in most response groups, but some older
      # response formats use "product_title" instead.
      WishlistItem.new(
        asin: data["asin"],
        title: data["title"] || data["product_title"],
        authors: authors,
        narrators: narrators
      )
    end
  end
end
