# frozen_string_literal: true

module Admin
  class IssuesController < BaseController
    before_action :set_request, only: [:retry, :cancel]

    def index
      @requests = Request.with_issues
                         .includes(:book, :user)
                         .order(updated_at: :desc)
    end

    def retry
      @request.retry_now!
      redirect_to admin_issues_path, notice: "Request for \"#{@request.book.title}\" has been queued for retry."
    end

    def cancel
      @request.cancel!
      redirect_to admin_issues_path, notice: "Request for \"#{@request.book.title}\" has been cancelled."
    end

    private

    def set_request
      @request = Request.find(params[:id])
    end
  end
end
