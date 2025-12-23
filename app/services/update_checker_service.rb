# frozen_string_literal: true

# Checks GitHub repository for available updates
class UpdateCheckerService
  class Error < StandardError; end

  Result = Data.define(:update_available, :current_version, :latest_version, :latest_message, :latest_date, :compare_url) do
    def update_available?
      update_available
    end
  end

  CACHE_KEY = "shelfarr:update_check"
  CACHE_TTL = 1.hour

  class << self
    # Check for updates (cached)
    def check(force: false)
      Rails.cache.delete(CACHE_KEY) if force

      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL) do
        perform_check
      end
    end

    # Get cached result without making API call
    def cached_result
      Rails.cache.read(CACHE_KEY)
    end

    # Clear cache
    def clear_cache
      Rails.cache.delete(CACHE_KEY)
    end

    private

    def perform_check
      current = current_version
      return no_update_result(current, "Not a git repository") unless current

      repo = github_repo
      return no_update_result(current, "GitHub repo not configured") unless repo

      latest = fetch_latest_commit(repo)
      return no_update_result(current, "Could not fetch latest version") unless latest

      Result.new(
        update_available: current != latest[:sha],
        current_version: current[0..6],
        latest_version: latest[:sha][0..6],
        latest_message: latest[:message],
        latest_date: latest[:date],
        compare_url: "https://github.com/#{repo}/compare/#{current[0..6]}...#{latest[:sha][0..6]}"
      )
    rescue => e
      Rails.logger.error "[UpdateChecker] Error checking for updates: #{e.message}"
      no_update_result(current_version, e.message)
    end

    def no_update_result(current, message = nil)
      Result.new(
        update_available: false,
        current_version: current&.slice(0, 7) || "unknown",
        latest_version: nil,
        latest_message: message,
        latest_date: nil,
        compare_url: nil
      )
    end

    def current_version
      # Try reading from GIT_COMMIT env var (set during docker build)
      return ENV["GIT_COMMIT"] if ENV["GIT_COMMIT"].present?

      # Try reading from VERSION file
      version_file = Rails.root.join("VERSION")
      return File.read(version_file).strip if File.exist?(version_file)

      # Try getting from git directly
      result = `git rev-parse HEAD 2>/dev/null`.strip
      result.present? ? result : nil
    end

    def github_repo
      SettingsService.get(:github_repo)
    end

    def fetch_latest_commit(repo)
      response = connection.get("/repos/#{repo}/commits/main")

      case response.status
      when 200
        data = response.body
        {
          sha: data["sha"],
          message: data.dig("commit", "message")&.lines&.first&.strip,
          date: data.dig("commit", "committer", "date")
        }
      when 404
        # Try master branch
        response = connection.get("/repos/#{repo}/commits/master")
        return nil unless response.status == 200

        data = response.body
        {
          sha: data["sha"],
          message: data.dig("commit", "message")&.lines&.first&.strip,
          date: data.dig("commit", "committer", "date")
        }
      else
        nil
      end
    end

    def connection
      @connection ||= Faraday.new(url: "https://api.github.com") do |f|
        f.request :json
        f.response :json, parser_options: { symbolize_names: false }
        f.adapter Faraday.default_adapter
        f.headers["Accept"] = "application/vnd.github.v3+json"
        f.headers["User-Agent"] = "Shelfarr"
        f.options.timeout = 10
        f.options.open_timeout = 5
      end
    end
  end
end
