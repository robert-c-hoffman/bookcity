class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :requests, dependent: :destroy
  has_many :uploads, dependent: :destroy
  has_many :notifications, dependent: :destroy

  enum :role, { user: 0, admin: 1 }, default: :user

  normalizes :username, with: ->(u) { u.strip.downcase }

  validates :username, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9_]+\z/, message: "only allows lowercase letters, numbers, and underscores" }
  validates :name, presence: true
  validates :password, length: { minimum: 8 }, if: -> { password.present? }

  before_create :set_admin_if_first_user

  private

  def set_admin_if_first_user
    self.role = :admin if User.count.zero?
  end
end
