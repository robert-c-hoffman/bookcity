# frozen_string_literal: true

class SearchController < ApplicationController
  def index
    @query = params[:q]
  end

  def results
    @query = params[:q].to_s.strip

    if @query.blank?
      @results = []
      @error = nil
    else
      begin
        @results = OpenLibraryClient.search(@query)
        @error = nil
      rescue OpenLibraryClient::ConnectionError => e
        @results = []
        @error = "Unable to connect to Open Library. Please try again later."
        Rails.logger.error("Open Library connection error: #{e.message}")
      rescue OpenLibraryClient::Error => e
        @results = []
        @error = "Search failed. Please try again."
        Rails.logger.error("Open Library error: #{e.message}")
      end
    end

    respond_to do |format|
      format.turbo_stream
      format.html { render :index }
    end
  end
end
