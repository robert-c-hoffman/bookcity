module ApplicationHelper
  # Returns the path for assets in the public folder, respecting RAILS_RELATIVE_URL_ROOT
  # Use this for static assets like /icon.png or /images/no-cover.svg
  def public_asset_path(path)
    # Use request.script_name which is set by Rack::URLMap when app is mounted at a subpath
    base = request.script_name.to_s
    "#{base}/#{path.to_s.delete_prefix('/')}"
  end

  # Format datetime in user's timezone
  def local_time(time, format = :default)
    return "" unless time

    timezone = Current.user&.timezone || "UTC"
    localized_time = time.in_time_zone(timezone)

    case format
    when :short
      localized_time.strftime("%b %d, %Y")
    when :long
      localized_time.strftime("%B %d, %Y at %I:%M %p %Z")
    when :datetime
      localized_time.strftime("%B %d, %Y at %I:%M %p")
    when :compact
      localized_time.strftime("%b %d, %H:%M")
    else
      localized_time.strftime("%B %d, %Y")
    end
  end
end
