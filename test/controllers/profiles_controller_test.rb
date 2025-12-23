# frozen_string_literal: true

require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "show requires authentication" do
    sign_out
    get profile_path
    assert_response :redirect
  end

  test "show displays user info" do
    get profile_path
    assert_response :success
    assert_select "h1", "My Profile"
    assert_select "h2", @user.name
  end

  test "show displays stats" do
    get profile_path
    assert_response :success
    # Check that stats are displayed (values depend on fixtures)
    assert_select ".bg-gray-50 p.text-2xl"
    assert_select ".bg-green-50 p.text-2xl"
    assert_select ".bg-yellow-50 p.text-2xl"
  end

  test "edit displays form" do
    get edit_profile_path
    assert_response :success
    assert_select "input[name='user[name]']"
  end

  test "update changes name" do
    patch profile_path, params: { user: { name: "New Name" } }
    assert_redirected_to profile_path
    assert_equal "New Name", @user.reload.name
  end

  test "update rejects blank name" do
    patch profile_path, params: { user: { name: "" } }
    assert_response :unprocessable_entity
    assert_select ".bg-red-50"
  end

  test "password page displays form" do
    get password_profile_path
    assert_response :success
    assert_select "input[name='current_password']"
    assert_select "input[name='user[password]']"
    assert_select "input[name='user[password_confirmation]']"
  end

  test "update_password requires current password" do
    patch update_password_profile_path, params: {
      current_password: "wrongpassword",
      user: { password: "newpassword123", password_confirmation: "newpassword123" }
    }
    assert_response :unprocessable_entity
    assert_select "li", /Current password is incorrect/
  end

  test "update_password changes password" do
    patch update_password_profile_path, params: {
      current_password: "password",
      user: { password: "newpassword123", password_confirmation: "newpassword123" }
    }
    assert_redirected_to profile_path
    assert @user.reload.authenticate("newpassword123")
  end

  test "update_password invalidates other sessions" do
    other_session = @user.sessions.create!

    patch update_password_profile_path, params: {
      current_password: "password",
      user: { password: "newpassword123", password_confirmation: "newpassword123" }
    }

    assert_redirected_to profile_path
    assert_not Session.exists?(other_session.id)
    assert Session.exists?(Current.session.id)
  end

  test "update_password requires matching confirmation" do
    patch update_password_profile_path, params: {
      current_password: "password",
      user: { password: "newpassword123", password_confirmation: "different" }
    }
    assert_response :unprocessable_entity
  end

  test "update_password requires minimum length" do
    patch update_password_profile_path, params: {
      current_password: "password",
      user: { password: "short", password_confirmation: "short" }
    }
    assert_response :unprocessable_entity
  end
end
