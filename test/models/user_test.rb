require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips username" do
    user = User.new(username: " MYUSER ")
    assert_equal("myuser", user.username)
  end

  test "validates username format" do
    user = User.new(name: "Test", username: "invalid user!", password: "password123")
    assert_not user.valid?
    assert user.errors[:username].any?
  end

  test "allows valid username characters" do
    user = User.new(name: "Test", username: "valid_user123", password: "password123")
    assert user.valid?
  end
end
