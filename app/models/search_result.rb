# frozen_string_literal: true

class SearchResult < ApplicationRecord
  belongs_to :request

  enum :status, {
    pending: 0,
    selected: 1,
    rejected: 2
  }

  validates :guid, presence: true, uniqueness: { scope: :request_id }
  validates :title, presence: true

  scope :selectable, -> { pending }

  # Sort by preferred download type, then by seeders
  # Usenet results: have download_url, no magnet_url, no seeders (NULL)
  # Torrent results: have magnet_url or seeders
  scope :preferred_first, -> {
    preferred = SettingsService.get(:preferred_download_type, default: "torrent")
    if preferred == "usenet"
      order(Arel.sql("CASE WHEN download_url IS NOT NULL AND magnet_url IS NULL AND seeders IS NULL THEN 0 ELSE 1 END"))
    else
      order(Arel.sql("CASE WHEN magnet_url IS NOT NULL THEN 0 ELSE 1 END"))
    end
  }

  scope :best_first, -> { preferred_first.order(seeders: :desc, size_bytes: :asc) }

  def downloadable?
    download_url.present? || magnet_url.present?
  end

  def download_link
    magnet_url.presence || download_url
  end

  # Check if this is a usenet/NZB result
  # Usenet results have: download URL, no magnet URL, no seeders
  # Torrent results have: magnet URL or seeders count
  def usenet?
    download_url.present? && magnet_url.blank? && seeders.nil?
  end

  # Check if this is a torrent result
  def torrent?
    magnet_url.present? || (download_url.present? && !usenet?)
  end

  def size_human
    return nil unless size_bytes

    ActiveSupport::NumberHelper.number_to_human_size(size_bytes)
  end
end
