# frozen_string_literal: true

# Recurring job that syncs the Audible wishlist and automatically creates
# download requests for audiobooks not already present in Audiobookshelf.
class AudibleWishlistSyncJob < ApplicationJob
  queue_as :default

  def perform
    unless AudibleClient.configured?
      Rails.logger.info "[AudibleWishlistSyncJob] Audible not configured, skipping"
      return
    end

    Rails.logger.info "[AudibleWishlistSyncJob] Starting Audible wishlist sync"

    wishlist = AudibleClient.wishlist
    Rails.logger.info "[AudibleWishlistSyncJob] Found #{wishlist.count} items in wishlist"

    system_user = User.where(role: :admin).order(:created_at).first
    unless system_user
      Rails.logger.error "[AudibleWishlistSyncJob] No admin user found, cannot create requests"
      return
    end

    wishlist.each do |item|
      process_wishlist_item(item, system_user)
    end
  rescue AudibleClient::AuthenticationError => e
    Rails.logger.error "[AudibleWishlistSyncJob] Authentication error: #{e.message}"
  rescue AudibleClient::Error => e
    Rails.logger.error "[AudibleWishlistSyncJob] Audible error: #{e.message}"
  ensure
    schedule_next_run
  end

  private

  def process_wishlist_item(item, user)
    return if item.title.blank?

    if exists_in_audiobookshelf?(item)
      Rails.logger.info "[AudibleWishlistSyncJob] Skipping '#{item.title}' - already in Audiobookshelf"
      return
    end

    book = find_or_create_book(item)

    if active_or_completed_request_exists?(book)
      Rails.logger.info "[AudibleWishlistSyncJob] Skipping '#{item.title}' - request already exists"
      return
    end

    create_request(book, user)
  rescue => e
    Rails.logger.error "[AudibleWishlistSyncJob] Error processing '#{item.title}': #{e.message}"
  end

  # Check the local Audiobookshelf library cache for a title match
  def exists_in_audiobookshelf?(item)
    return false unless AudiobookshelfClient.configured?

    audiobook_library_id = SettingsService.get(:audiobookshelf_audiobook_library_id)
    library_ids = [ audiobook_library_id ].compact.reject(&:blank?)
    return false if library_ids.empty?

    LibraryItem.for_libraries(library_ids).any? do |cached_item|
      titles_match?(cached_item.title, item.title)
    end
  end

  def titles_match?(title1, title2)
    normalize_title(title1) == normalize_title(title2)
  end

  # Normalize a title for comparison: lowercase, remove diacritics via NFKD
  # decomposition, strip non-alphanumeric characters, and collapse whitespace.
  def normalize_title(text)
    text.to_s.downcase.unicode_normalize(:nfkd).gsub(/[^a-z0-9\s]/, "").squeeze(" ").strip
  end

  def find_or_create_book(item)
    # First try to find by ASIN stored in the isbn column
    if item.asin.present?
      book = Book.find_by(isbn: item.asin, book_type: :audiobook)
      return book if book
    end

    # Fall back to matching by normalized title using SQL for efficiency,
    # with an in-Ruby normalization check to handle diacritics and punctuation.
    normalized = normalize_title(item.title)
    book = Book.audiobooks
               .where("lower(title) = lower(?)", item.title)
               .find { |b| normalize_title(b.title) == normalized }
    return book if book

    Book.create!(
      title: item.title,
      author: item.author.presence,
      narrator: item.narrator.presence,
      book_type: :audiobook,
      isbn: item.asin.presence
    )
  end

  def active_or_completed_request_exists?(book)
    book.requests.where(status: [ :pending, :searching, :downloading, :processing, :completed ]).exists?
  end

  def create_request(book, user)
    request = Request.create!(
      book: book,
      user: user,
      status: :pending
    )

    Rails.logger.info "[AudibleWishlistSyncJob] Created request ##{request.id} for '#{book.title}'"
    ActivityTracker.track("request.created", trackable: request, user: user)

    SearchJob.perform_later(request.id) if SettingsService.get(:immediate_search_enabled, default: false)

    request
  end

  def schedule_next_run
    interval = SettingsService.get(:audible_wishlist_sync_interval, default: 3600).to_i
    return if interval <= 0

    AudibleWishlistSyncJob.set(wait: interval.seconds).perform_later
  end
end
