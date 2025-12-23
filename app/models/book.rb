class Book < ApplicationRecord
  has_many :requests, dependent: :restrict_with_error
  has_many :uploads, dependent: :nullify

  enum :book_type, { audiobook: 0, ebook: 1 }

  validates :title, presence: true
  validates :book_type, presence: true

  scope :audiobooks, -> { where(book_type: :audiobook) }
  scope :ebooks, -> { where(book_type: :ebook) }
  scope :acquired, -> { where.not(file_path: nil) }
  scope :pending, -> { where(file_path: nil) }

  def acquired?
    file_path.present?
  end

  def display_name
    author.present? ? "#{title} by #{author}" : title
  end
end
