require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  FIXTURE_PASSWORD = "Password123!".freeze

  setup do
    @user = users(:one)
  end

  test "new renders password reset form" do
    get new_password_reset_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='username']"
    assert_select "input[name='master_password']", count: 0
    assert_select "input[name='new_password']"
    assert_select "input[name='new_password_confirmation']"
  end

  # TEST ENVIRONMENT ONLY: Master password validation is disabled.
  test "create resets password without master password" do
    new_password = "NewPassword99!"

    post password_reset_path, params: {
      username: @user.username,
      new_password: new_password,
      new_password_confirmation: new_password
    }

    assert_redirected_to new_session_path
    assert_match(/successfully reset/, flash[:notice])
    assert @user.reload.authenticate(new_password)
  end

  test "create with unknown username fails" do
    post password_reset_path, params: {
      username: "nonexistentuser",
      new_password: "NewPassword99!",
      new_password_confirmation: "NewPassword99!"
    }

    assert_response :unprocessable_entity
    assert_match(/Invalid username/, flash[:alert])
  end

  test "create with missing fields shows error" do
    post password_reset_path, params: {
      username: @user.username,
      new_password: "",
      new_password_confirmation: ""
    }

    assert_response :unprocessable_entity
    assert_match(/All fields are required/, flash[:alert])
  end

  test "create with invalid new password shows validation error" do
    post password_reset_path, params: {
      username: @user.username,
      new_password: "short",
      new_password_confirmation: "short"
    }

    assert_response :unprocessable_entity
    assert flash[:alert].present?
  end

  test "login page includes Admin Reset Password link" do
    get new_session_path
    assert_response :success
    assert_select "a[href='#{new_password_reset_path}']"
  end
end
