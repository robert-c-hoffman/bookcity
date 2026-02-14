# frozen_string_literal: true

require "test_helper"

class HardcoverClientTest < ActiveSupport::TestCase
  setup do
    @original_token = SettingsService.get(:hardcover_api_token)
    HardcoverClient.reset_connection!
  end

  teardown do
    SettingsService.set(:hardcover_api_token, @original_token || "")
    HardcoverClient.reset_connection!
  end

  test "configured? returns false without token" do
    SettingsService.set(:hardcover_api_token, "")
    assert_not HardcoverClient.configured?
  end

  test "configured? returns true with token" do
    SettingsService.set(:hardcover_api_token, "test_token")
    assert HardcoverClient.configured?
  end

  test "search raises NotConfiguredError without token" do
    SettingsService.set(:hardcover_api_token, "")

    assert_raises HardcoverClient::NotConfiguredError do
      HardcoverClient.search("test")
    end
  end

  test "search returns array of SearchResult" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      stub_hardcover_search("lord of the rings", [
        { "document" => {
          "id" => 123, "title" => "The Lord of the Rings", "author_names" => [ "J.R.R. Tolkien" ],
          "release_year" => 1954, "cached_image" => "https://example.com/cover.jpg",
          "has_audiobook" => true, "has_ebook" => true
        } }
      ])

      results = HardcoverClient.search("lord of the rings")

      assert_kind_of Array, results
      assert_equal 1, results.size
      assert_kind_of HardcoverClient::SearchResult, results.first

      result = results.first
      assert_equal "The Lord of the Rings", result.title
      assert_equal "J.R.R. Tolkien", result.author
      assert_equal 1954, result.release_year
      assert result.has_audiobook
      assert result.has_ebook
    end
  end

  test "search handles empty results" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      stub_hardcover_search("asdfghjklqwertyuiop", [])

      results = HardcoverClient.search("asdfghjklqwertyuiop")
      assert_equal [], results
    end
  end

  test "search handles real-world API response structure with hits" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      # Simulate the exact structure from the logs with multiple books in hits
      stub_hardcover_search("Roverpowered", [
        { "document" => {
          "id" => 123, "title" => "Roverpowered", "author_names" => [ "Drew Hayes" ],
          "release_year" => 2020, "cached_image" => "https://example.com/cover.jpg",
          "has_audiobook" => true, "has_ebook" => true
        } },
        { "document" => {
          "id" => 456, "title" => "Roverpowered 2", "author_names" => [ "Drew Hayes" ],
          "release_year" => 2021, "cached_image" => "https://example.com/cover2.jpg",
          "has_audiobook" => true, "has_ebook" => false
        } }
      ])

      results = HardcoverClient.search("Roverpowered")

      assert_kind_of Array, results
      assert_equal 2, results.size
      assert_equal "Roverpowered", results.first.title
      assert_equal "Drew Hayes", results.first.author
      assert_equal "Roverpowered 2", results.last.title
    end
  end

  test "search handles legacy array response format" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      # Simulate legacy format where results is an array directly
      stub_request(:post, HardcoverClient::BASE_URL)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            "data" => {
              "search" => {
                "results" => [
                  { "document" => {
                    "id" => 789, "title" => "Legacy Book", "author_names" => [ "Legacy Author" ],
                    "release_year" => 2019, "cached_image" => "https://example.com/legacy.jpg",
                    "has_audiobook" => false, "has_ebook" => true
                  } }
                ]
              }
            }
          }.to_json
        )

      results = HardcoverClient.search("Legacy")

      assert_kind_of Array, results
      assert_equal 1, results.size
      assert_equal "Legacy Book", results.first.title
    end
  end

  test "search handles unexpected response format gracefully" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      # Simulate unexpected format (string instead of hash or array)
      stub_request(:post, HardcoverClient::BASE_URL)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: {
            "data" => {
              "search" => {
                "results" => "unexpected string"
              }
            }
          }.to_json
        )

      results = HardcoverClient.search("Unexpected")

      assert_kind_of Array, results
      assert_equal 0, results.size
    end
  end

  test "book returns BookDetails" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      stub_hardcover_book(12345, {
        "id" => 12345,
        "title" => "Test Book",
        "description" => "A test description",
        "release_year" => 2020,
        "cached_image" => "https://example.com/cover.jpg",
        "contributions" => [ { "author" => { "name" => "Test Author" } } ],
        "default_physical_edition" => { "pages" => 300 },
        "book_series" => [ { "series" => { "name" => "Test Series" } } ]
      })

      book = HardcoverClient.book(12345)

      assert_kind_of HardcoverClient::BookDetails, book
      assert_equal "Test Book", book.title
      assert_equal "Test Author", book.author
      assert_equal 2020, book.release_year
      assert_equal 300, book.pages
      assert_equal "Test Series", book.series_name
    end
  end

  test "book raises NotFoundError for invalid id" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      stub_hardcover_book(999999999, nil)

      assert_raises HardcoverClient::NotFoundError do
        HardcoverClient.book(999999999)
      end
    end
  end

  test "handles authentication error" do
    SettingsService.set(:hardcover_api_token, "invalid_token")

    VCR.turned_off do
      stub_request(:post, HardcoverClient::BASE_URL)
        .to_return(status: 401, body: '{"error": "Unauthorized"}')

      assert_raises HardcoverClient::AuthenticationError do
        HardcoverClient.search("test")
      end
    end
  end

  test "handles rate limit error" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      stub_request(:post, HardcoverClient::BASE_URL)
        .to_return(status: 429, body: '{"error": "Rate limit exceeded"}')

      assert_raises HardcoverClient::RateLimitError do
        HardcoverClient.search("test")
      end
    end
  end

  test "test_connection returns true on success" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      stub_request(:post, HardcoverClient::BASE_URL)
        .to_return(
          status: 200,
          headers: { "Content-Type" => "application/json" },
          body: { "data" => { "me" => { "id" => 123 } } }.to_json
        )

      assert HardcoverClient.test_connection
    end
  end

  test "test_connection returns false on auth failure" do
    SettingsService.set(:hardcover_api_token, "invalid_token")

    VCR.turned_off do
      stub_request(:post, HardcoverClient::BASE_URL)
        .to_return(status: 401, body: '{"error": "Unauthorized"}')

      assert_not HardcoverClient.test_connection
    end
  end

  test "work_id includes source prefix" do
    result = HardcoverClient::SearchResult.new(
      id: "12345",
      title: "Test",
      author: "Author",
      description: nil,
      release_year: 2020,
      cover_url: nil,
      has_audiobook: true,
      has_ebook: true
    )

    assert_equal "hardcover:12345", result.work_id
  end

  test "search handles cached_image as JSON object" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      stub_hardcover_search("test", [
        { "document" => {
          "id" => 456,
          "title" => "Test Book",
          "author_names" => [ "Test Author" ],
          "release_year" => 2023,
          "cached_image" => { "url" => "https://example.com/cover.jpg", "width" => 512, "height" => 768 },
          "has_audiobook" => true,
          "has_ebook" => false
        } }
      ])

      results = HardcoverClient.search("test")

      assert_kind_of Array, results
      assert_equal 1, results.size
      result = results.first
      assert_equal "Test Book", result.title
      assert_equal "https://example.com/cover.jpg", result.cover_url
      assert result.has_audiobook
      assert_not result.has_ebook
    end
  end

  test "search handles fields at result level instead of document" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      # Real-world API may return some fields at result level, not nested in document
      stub_hardcover_search("test", [
        {
          "cached_image" => "https://example.com/result-level-cover.jpg",
          "has_audiobook" => true,
          "has_ebook" => true,
          "author_names" => [ "Result Level Author" ],
          "document" => {
            "id" => 789,
            "title" => "Result Level Book",
            "release_year" => 2024
          }
        }
      ])

      results = HardcoverClient.search("test")

      assert_kind_of Array, results
      assert_equal 1, results.size
      result = results.first
      assert_equal "Result Level Book", result.title
      assert_equal "Result Level Author", result.author
      assert_equal "https://example.com/result-level-cover.jpg", result.cover_url
      assert result.has_audiobook
      assert result.has_ebook
    end
  end

  test "search handles mixed result and document fields" do
    SettingsService.set(:hardcover_api_token, "test_token")

    VCR.turned_off do
      # Some fields at result level, some in document - prefers result level
      stub_hardcover_search("test", [
        {
          "cached_image" => "https://example.com/result-cover.jpg",
          "has_audiobook" => true,
          "document" => {
            "id" => 999,
            "title" => "Mixed Level Book",
            "author_names" => [ "Mixed Author" ],
            "release_year" => 2025,
            "cached_image" => "https://example.com/document-cover.jpg",
            "has_ebook" => false
          }
        }
      ])

      results = HardcoverClient.search("test")

      assert_kind_of Array, results
      assert_equal 1, results.size
      result = results.first
      # Should prefer result level over document level
      assert_equal "https://example.com/result-cover.jpg", result.cover_url
      assert result.has_audiobook
      assert_not result.has_ebook
    end
  end

  private

  def stub_hardcover_search(query, results)
    # Hardcover API returns results as a hash with metadata, not just an array
    results_hash = {
      "hits" => results,
      "found" => results.size,
      "page" => 1,
      "out_of" => 2229375, # Total number of books in the database
      "facet_counts" => [],
      "search_time_ms" => 1,
      "search_cutoff" => false,
      "request_params" => { "q" => query, "per_page" => 10 }
    }

    stub_request(:post, HardcoverClient::BASE_URL)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { "data" => { "search" => { "results" => results_hash } } }.to_json
      )
  end

  def stub_hardcover_book(id, book_data)
    books = book_data ? [ book_data ] : []
    stub_request(:post, HardcoverClient::BASE_URL)
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { "data" => { "books" => books } }.to_json
      )
  end
end
