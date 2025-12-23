# frozen_string_literal: true

class DownloadClient < ApplicationRecord
  encrypts :password, :api_key

  enum :client_type, { qbittorrent: "qbittorrent", sabnzbd: "sabnzbd" }

  has_many :downloads, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :client_type, presence: true
  validates :url, presence: true
  validates :priority, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :enabled, -> { where(enabled: true) }
  scope :by_priority, -> { order(priority: :asc) }
  scope :torrent_clients, -> { where(client_type: :qbittorrent) }
  scope :usenet_clients, -> { where(client_type: :sabnzbd) }

  def adapter
    case client_type
    when "qbittorrent"
      DownloadClients::Qbittorrent.new(self)
    when "sabnzbd"
      DownloadClients::Sabnzbd.new(self)
    end
  end

  def test_connection
    adapter.test_connection
  rescue StandardError
    false
  end

  def torrent_client?
    qbittorrent?
  end

  def usenet_client?
    sabnzbd?
  end
end
