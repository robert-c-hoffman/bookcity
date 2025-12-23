# frozen_string_literal: true

class LibraryController < ApplicationController
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  def index
    @books = Book.acquired.includes(:requests).order(updated_at: :desc)
    @books = @books.where(book_type: params[:type]) if params[:type].present?
  end

  def show
    @book = Book.acquired.find(params[:id])
    @user_request = @book.requests.find_by(user: Current.user)
  end

  private

  def record_not_found
    head :not_found
  end
end
