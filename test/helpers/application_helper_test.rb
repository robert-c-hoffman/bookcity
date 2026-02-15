require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "local_time formats time in user timezone" do
    user = users(:one)
    user.update!(timezone: "America/New_York")
    
    # Mock Current.user
    Current.user = user
    
    time = Time.zone.parse("2024-01-15 12:00:00 UTC")
    result = local_time(time, :long)
    
    # Result should include EST/EDT timezone indicator
    assert_includes result, "January 15, 2024"
    assert_includes result, ["EST", "EDT"] # Timezone abbreviation
  end

  test "local_time defaults to UTC when user has no timezone" do
    user = users(:one)
    user.update!(timezone: nil)
    
    Current.user = user
    
    time = Time.zone.parse("2024-01-15 12:00:00 UTC")
    result = local_time(time, :long)
    
    assert_includes result, "January 15, 2024"
  end

  test "local_time formats short format" do
    user = users(:one)
    user.update!(timezone: "UTC")
    
    Current.user = user
    
    time = Time.zone.parse("2024-01-15 12:00:00 UTC")
    result = local_time(time, :short)
    
    assert_equal "Jan 15, 2024", result
  end

  test "local_time formats datetime format" do
    user = users(:one)
    user.update!(timezone: "UTC")
    
    Current.user = user
    
    time = Time.zone.parse("2024-01-15 14:30:00 UTC")
    result = local_time(time, :datetime)
    
    assert_equal "January 15, 2024 at 02:30 PM", result
  end

  test "local_time formats compact format" do
    user = users(:one)
    user.update!(timezone: "UTC")
    
    Current.user = user
    
    time = Time.zone.parse("2024-01-15 14:30:00 UTC")
    result = local_time(time, :compact)
    
    assert_equal "Jan 15, 14:30", result
  end

  test "local_time returns empty string for nil time" do
    result = local_time(nil)
    assert_equal "", result
  end

  test "local_time works when Current.user is nil" do
    Current.user = nil
    
    time = Time.zone.parse("2024-01-15 12:00:00 UTC")
    result = local_time(time)
    
    # Should use UTC as default
    assert_includes result, "January 15, 2024"
  end
end
