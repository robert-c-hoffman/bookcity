require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  FIXTURE_PASSWORD = "Password123!".freeze

  setup do
    @user = users(:one)
  end

  teardown do
    ENV.delete("MASTER_PASSWORD")
  end

  test "new renders password reset form" do
    get new_password_reset_path
    assert_response :success
    assert_select "form"
    assert_select "input[name='username']"
    assert_select "input[name='master_password']"
    assert_select "input[name='new_password']"
    assert_select "input[name='new_password_confirmation']"
  end

  test "create with correct master password resets password" do
    ENV["MASTER_PASSWORD"] = "CorrectMasterPass1!"
    new_password = "NewPassword99!"

    post password_reset_path, params: {
      username: @user.username,
      master_password: "CorrectMasterPass1!",
      new_password: new_password,
      new_password_confirmation: new_password
    }

    assert_redirected_to new_session_path
    assert_match(/successfully reset/, flash[:notice])
    assert @user.reload.authenticate(new_password)
  end

  test "create with wrong master password fails" do
    ENV["MASTER_PASSWORD"] = "CorrectMasterPass1!"

    post password_reset_path, params: {
      username: @user.username,
      master_password: "WrongMasterPass1!",
      new_password: "NewPassword99!",
      new_password_confirmation: "NewPassword99!"
    }

    assert_response :unprocessable_entity
    assert_match(/Invalid username or master password/, flash[:alert])
  end

  test "create with unknown username fails without leaking info" do
    ENV["MASTER_PASSWORD"] = "CorrectMasterPass1!"

    post password_reset_path, params: {
      username: "nonexistentuser",
      master_password: "CorrectMasterPass1!",
      new_password: "NewPassword99!",
      new_password_confirmation: "NewPassword99!"
    }

    assert_response :unprocessable_entity
    assert_match(/Invalid username or master password/, flash[:alert])
  end

  test "create when MASTER_PASSWORD not configured fails" do
    ENV.delete("MASTER_PASSWORD")

    post password_reset_path, params: {
      username: @user.username,
      master_password: "anything",
      new_password: "NewPassword99!",
      new_password_confirmation: "NewPassword99!"
    }

    assert_response :unprocessable_entity
    assert_match(/not configured/, flash[:alert])
  end

  test "create with missing fields shows error" do
    post password_reset_path, params: {
      username: @user.username,
      master_password: "",
      new_password: "NewPassword99!",
      new_password_confirmation: "NewPassword99!"
    }

    assert_response :unprocessable_entity
    assert_match(/All fields are required/, flash[:alert])
  end

  test "create with invalid new password shows validation error" do
    ENV["MASTER_PASSWORD"] = "CorrectMasterPass1!"

    post password_reset_path, params: {
      username: @user.username,
      master_password: "CorrectMasterPass1!",
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
