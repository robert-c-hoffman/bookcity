# frozen_string_literal: true

# Service for automatically selecting the best search result for a request
class AutoSelectService
  # Result object for selection outcomes
  class SelectionResult
    attr_reader :selected, :reason, :search_result

    def initialize(selected:, reason:, search_result: nil)
      @selected = selected
      @reason = reason
      @search_result = search_result
    end

    def success?
      @selected
    end
  end

  def self.call(request)
    new(request).call
  end

  def initialize(request)
    @request = request
    @min_seeders = SettingsService.get(:auto_select_min_seeders, default: 1)
  end

  def call
    candidates = @request.search_results.pending.best_first.select(&:downloadable?)

    if candidates.empty?
      log_skip("no downloadable results")
      return SelectionResult.new(selected: false, reason: :no_downloadable_results)
    end

    best_result = candidates.first

    unless meets_seeder_threshold?(best_result)
      log_skip("best result has #{best_result.seeders || 0} seeders, minimum is #{@min_seeders}")
      return SelectionResult.new(selected: false, reason: :below_seeder_threshold, search_result: best_result)
    end

    @request.select_result!(best_result)
    log_success(best_result)
    SelectionResult.new(selected: true, reason: :auto_selected, search_result: best_result)
  rescue => e
    Rails.logger.error "[AutoSelectService] Error for request ##{@request.id}: #{e.message}"
    SelectionResult.new(selected: false, reason: :error)
  end

  private

  def meets_seeder_threshold?(result)
    return true if result.usenet? # Usenet has no seeders
    (result.seeders || 0) >= @min_seeders
  end

  def log_success(result)
    Rails.logger.info "[AutoSelectService] Auto-selected '#{result.title}' for request ##{@request.id}"
  end

  def log_skip(reason)
    Rails.logger.info "[AutoSelectService] Skipped for request ##{@request.id}: #{reason}"
  end
end
