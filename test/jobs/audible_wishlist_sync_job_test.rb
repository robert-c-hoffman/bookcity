# frozen_string_literal: true

require "test_helper"

class AudibleWishlistSyncJobTest < ActiveJob::TestCase
  setup do
    AudibleClient.reset_connection!
    SettingsService.set(:audible_enabled, true)
    SettingsService.set(:audible_access_token, "test-audible-token")
    SettingsService.set(:audible_country_code, "us")
    SettingsService.set(:audible_wishlist_sync_interval, 3600)
    SettingsService.set(:audiobookshelf_url, "http://localhost:13378")
    SettingsService.set(:audiobookshelf_api_key, "abs-test-key")
    SettingsService.set(:audiobookshelf_audiobook_library_id, "lib-audio")
    SettingsService.set(:immediate_search_enabled, false)

    LibraryItem.destroy_all
    AudiobookshelfClient.reset_connection!
  end

  teardown do
    AudibleClient.reset_connection!
    AudiobookshelfClient.reset_connection!
  end

  test "schedules next run after syncing" do
    VCR.turned_off do
      stub_audible_wishlist([])

      assert_enqueued_with(job: AudibleWishlistSyncJob) do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "schedules next run even when Audible raises an error" do
    VCR.turned_off do
      stub_request(:get, "https://api.audible.com/1.0/wishlist")
        .to_return(status: 500)

      assert_enqueued_with(job: AudibleWishlistSyncJob) do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "does not reschedule when interval is zero" do
    SettingsService.set(:audible_wishlist_sync_interval, 0)

    VCR.turned_off do
      stub_audible_wishlist([])

      assert_no_enqueued_jobs(only: AudibleWishlistSyncJob) do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "skips when Audible is not configured" do
    SettingsService.set(:audible_enabled, false)

    # No HTTP requests should be made
    assert_no_enqueued_jobs(only: SearchJob) do
      AudibleWishlistSyncJob.perform_now
    end
    assert_equal 0, Request.count
  end

  test "creates a request for a new wishlist item" do
    Book.audiobooks.destroy_all
    Request.where(book: Book.audiobooks).destroy_all

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001NEWBOOK", "title" => "Brand New Audiobook",
          "authors" => [ { "name" => "Great Author" } ], "narrators" => [] }
      ])

      assert_difference "Request.count", 1 do
        AudibleWishlistSyncJob.perform_now
      end

      request = Request.last
      assert request.pending?
      assert_equal "Brand New Audiobook", request.book.title
      assert_equal "Great Author", request.book.author
      assert request.book.audiobook?
    end
  end

  test "stores ASIN in the isbn column when creating a book" do
    Book.audiobooks.destroy_all

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001ASINTEST", "title" => "ASIN Test Book",
          "authors" => [ { "name" => "Some Author" } ], "narrators" => [] }
      ])

      AudibleWishlistSyncJob.perform_now

      book = Book.find_by(isbn: "B001ASINTEST")
      assert_not_nil book
      assert_equal "ASIN Test Book", book.title
    end
  end

  test "skips item already present in Audiobookshelf library cache" do
    LibraryItem.create!(library_id: "lib-audio", audiobookshelf_id: "abs-existing-1",
                        title: "Already Owned Audiobook", author: "Some Author")

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001EXISTING", "title" => "Already Owned Audiobook",
          "authors" => [ { "name" => "Some Author" } ], "narrators" => [] }
      ])

      assert_no_difference "Request.count" do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "title matching is case-insensitive and ignores punctuation" do
    LibraryItem.create!(library_id: "lib-audio", audiobookshelf_id: "abs-punct-1",
                        title: "The Hero's Journey!", author: "Author X")

    VCR.turned_off do
      # Wishlist title differs in punctuation and casing
      stub_audible_wishlist([
        { "asin" => "B001PUNCT", "title" => "the heros journey",
          "authors" => [ { "name" => "Author X" } ], "narrators" => [] }
      ])

      assert_no_difference "Request.count" do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "skips item that already has an active request" do
    book = Book.create!(title: "Existing Request Book", book_type: :audiobook,
                        isbn: "B001EXISTREQ")
    Request.create!(book: book, user: users(:one), status: :downloading)

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001EXISTREQ", "title" => "Existing Request Book",
          "authors" => [ { "name" => "Author" } ], "narrators" => [] }
      ])

      assert_no_difference "Request.count" do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "skips item that already has a completed request" do
    book = Book.create!(title: "Completed Book", book_type: :audiobook,
                        isbn: "B001COMPLETE")
    Request.create!(book: book, user: users(:one), status: :completed,
                    completed_at: 1.day.ago)

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001COMPLETE", "title" => "Completed Book",
          "authors" => [ { "name" => "Author" } ], "narrators" => [] }
      ])

      assert_no_difference "Request.count" do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "creates request for item with failed request (can retry)" do
    book = Book.create!(title: "Failed Before Book", book_type: :audiobook,
                        isbn: "B001FAILED")
    Request.create!(book: book, user: users(:one), status: :failed)

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001FAILED", "title" => "Failed Before Book",
          "authors" => [ { "name" => "Author" } ], "narrators" => [] }
      ])

      assert_difference "Request.count", 1 do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "does not trigger immediate search when disabled" do
    Book.audiobooks.destroy_all
    SettingsService.set(:immediate_search_enabled, false)

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001NOSEARCH", "title" => "No Immediate Search Book",
          "authors" => [ { "name" => "Author" } ], "narrators" => [] }
      ])

      assert_no_enqueued_jobs(only: SearchJob) do
        AudibleWishlistSyncJob.perform_now
      end

      assert_equal 1, Request.where(status: :pending).count
    end
  end

  test "triggers immediate search when enabled" do
    Book.audiobooks.destroy_all
    SettingsService.set(:immediate_search_enabled, true)

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001SEARCH", "title" => "Immediate Search Book",
          "authors" => [ { "name" => "Author" } ], "narrators" => [] }
      ])

      assert_enqueued_with(job: SearchJob) do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "skips items with blank titles" do
    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001NOTITLE", "title" => "",
          "authors" => [ { "name" => "Author" } ], "narrators" => [] }
      ])

      assert_no_difference "Request.count" do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "processes multiple wishlist items" do
    Book.audiobooks.destroy_all

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001MULTI1", "title" => "Book One",
          "authors" => [ { "name" => "Author One" } ], "narrators" => [] },
        { "asin" => "B001MULTI2", "title" => "Book Two",
          "authors" => [ { "name" => "Author Two" } ], "narrators" => [] }
      ])

      assert_difference "Request.count", 2 do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  test "skips check when audiobookshelf library id is not configured" do
    SettingsService.set(:audiobookshelf_audiobook_library_id, "")
    Book.audiobooks.destroy_all

    VCR.turned_off do
      stub_audible_wishlist([
        { "asin" => "B001NOLIBID", "title" => "No Library ID Book",
          "authors" => [ { "name" => "Author" } ], "narrators" => [] }
      ])

      # Without library ID, no cache check is done, so request should be created
      assert_difference "Request.count", 1 do
        AudibleWishlistSyncJob.perform_now
      end
    end
  end

  private

  def stub_audible_wishlist(products)
    stub_request(:get, "https://api.audible.com/1.0/wishlist")
      .with(query: hash_including("page" => "0"))
      .to_return(
        status: 200,
        headers: { "Content-Type" => "application/json" },
        body: { "products" => products }.to_json
      )
  end
end
