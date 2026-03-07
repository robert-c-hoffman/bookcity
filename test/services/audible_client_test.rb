# frozen_string_literal: true

require "test_helper"

class AudibleClientTest < ActiveSupport::TestCase
  setup do
    AudibleClient.reset_connection!
    SettingsService.set(:audible_enabled, true)
    SettingsService.set(:audible_access_token, "test-audible-token-12345")
    SettingsService.set(:audible_country_code, "us")
  end

  teardown do
    AudibleClient.reset_connection!
  end

  test "configured? returns true when enabled with an access token" do
    assert AudibleClient.configured?
  end

  test "configured? returns false when disabled" do
    SettingsService.set(:audible_enabled, false)
    assert_not AudibleClient.configured?
  end

  test "configured? returns false when access token is blank" do
    SettingsService.set(:audible_access_token, "")
    assert_not AudibleClient.configured?
  end

  test "wishlist returns parsed wishlist items" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .with(
          headers: { "Authorization" => "Bearer test-audible-token-12345" },
          query: hash_including("num_results" => "50", "page" => "0")
        )
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            "products" => [
              {
                "asin" => "B001234567",
                "title" => "The Great Audiobook",
                "authors" => [ { "name" => "Jane Author" } ],
                "narrators" => [ { "name" => "John Narrator" } ]
              },
              {
                "asin" => "B007654321",
                "title" => "Another Audiobook",
                "authors" => [ { "name" => "Bob Writer" }, { "name" => "Alice Writer" } ],
                "narrators" => []
              }
            ]
          }.to_json
        )

      items = AudibleClient.wishlist

      assert_equal 2, items.size

      first = items.first
      assert_equal "B001234567", first.asin
      assert_equal "The Great Audiobook", first.title
      assert_equal "Jane Author", first.author
      assert_equal "John Narrator", first.narrator

      second = items.last
      assert_equal "Bob Writer, Alice Writer", second.author
      assert_equal "", second.narrator
    end
  end

  test "wishlist paginates through all results" do
    VCR.turned_off do
      # First page - full 50 items (use a simple repeated item for brevity)
      full_page = Array.new(50) { |i|
        { "asin" => "B#{i.to_s.rjust(9, '0')}", "title" => "Book #{i}", "authors" => [], "narrators" => [] }
      }
      # Second page - fewer than 50, triggering stop
      last_page = [ { "asin" => "B999999999", "title" => "Last Book", "authors" => [], "narrators" => [] } ]

      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .with(query: hash_including("page" => "0"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { "products" => full_page }.to_json)

      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .with(query: hash_including("page" => "1"))
        .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: { "products" => last_page }.to_json)

      items = AudibleClient.wishlist
      assert_equal 51, items.size
    end
  end

  test "wishlist raises AuthenticationError on 401" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_return(status: 401)

      assert_raises(AudibleClient::AuthenticationError) do
        AudibleClient.wishlist
      end
    end
  end

  test "wishlist raises AuthenticationError on 403" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_return(status: 403)

      assert_raises(AudibleClient::AuthenticationError) do
        AudibleClient.wishlist
      end
    end
  end

  test "wishlist raises Error on unexpected status" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_return(status: 500)

      assert_raises(AudibleClient::Error) do
        AudibleClient.wishlist
      end
    end
  end

  test "wishlist raises ConnectionError on network failure" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_raise(Faraday::ConnectionFailed.new("connection refused"))

      assert_raises(AudibleClient::ConnectionError) do
        AudibleClient.wishlist
      end
    end
  end

  test "test_connection returns true on success" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { "products" => [] }.to_json
        )

      assert AudibleClient.test_connection
    end
  end

  test "test_connection returns false on error" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_return(status: 401)

      assert_not AudibleClient.test_connection
    end
  end

  test "raises NotConfiguredError when not configured" do
    SettingsService.set(:audible_enabled, false)

    assert_raises(AudibleClient::NotConfiguredError) do
      AudibleClient.wishlist
    end
  end

  test "uses correct base URL for UK marketplace" do
    AudibleClient.reset_connection!
    SettingsService.set(:audible_country_code, "uk")

    VCR.turned_off do
      stub_request(:get, "https://api.audible.co.uk/1.0/wishlist")
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { "products" => [] }.to_json
        )

      items = AudibleClient.wishlist
      assert_equal [], items
    end
  ensure
    AudibleClient.reset_connection!
    SettingsService.set(:audible_country_code, "us")
  end

  test "uses US URL for unknown country code" do
    AudibleClient.reset_connection!
    SettingsService.set(:audible_country_code, "xx")

    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { "products" => [] }.to_json
        )

      items = AudibleClient.wishlist
      assert_equal [], items
    end
  ensure
    AudibleClient.reset_connection!
    SettingsService.set(:audible_country_code, "us")
  end

  test "WishlistItem#author joins multiple author names" do
    item = AudibleClient::WishlistItem.new(
      asin: "B001",
      title: "Multi-author Book",
      authors: [ "Author One", "Author Two" ],
      narrators: []
    )

    assert_equal "Author One, Author Two", item.author
  end

  test "WishlistItem#narrator joins multiple narrator names" do
    item = AudibleClient::WishlistItem.new(
      asin: "B001",
      title: "A Book",
      authors: [],
      narrators: [ "Narrator A", "Narrator B" ]
    )

    assert_equal "Narrator A, Narrator B", item.narrator
  end
end
