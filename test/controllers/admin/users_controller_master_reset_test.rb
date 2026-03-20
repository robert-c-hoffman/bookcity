require "test_helper"

module Admin
  class UsersControllerMasterResetTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:two)
      @user = users(:one)
      sign_in_as(@admin)
    end

    teardown do
      ENV.delete("MASTER_PASSWORD")
    end

    test "master_password_reset page renders successfully" do
      get master_password_reset_admin_user_path(@user)
      assert_response :success
    end

    test "perform_master_password_reset with correct master password resets password" do
      ENV["MASTER_PASSWORD"] = "CorrectMasterPass1!"
      new_password = "NewPassword99!"

      patch perform_master_password_reset_admin_user_path(@user), params: {
        master_password: "CorrectMasterPass1!",
        new_password: new_password,
        new_password_confirmation: new_password
      }

      assert_redirected_to admin_users_path
      assert_match(/Password for #{@user.username} was successfully reset/, flash[:notice])
      assert @user.reload.authenticate(new_password)
    end

    test "perform_master_password_reset with wrong master password fails" do
      ENV["MASTER_PASSWORD"] = "CorrectMasterPass1!"

      patch perform_master_password_reset_admin_user_path(@user), params: {
        master_password: "WrongMasterPass1!",
        new_password: "NewPassword99!",
        new_password_confirmation: "NewPassword99!"
      }

      assert_response :unprocessable_entity
      assert_match(/Invalid master password/, flash[:alert])
    end

    test "perform_master_password_reset when MASTER_PASSWORD not set fails" do
      ENV.delete("MASTER_PASSWORD")

      patch perform_master_password_reset_admin_user_path(@user), params: {
        master_password: "anything",
        new_password: "NewPassword99!",
        new_password_confirmation: "NewPassword99!"
      }

      assert_response :unprocessable_entity
      assert_match(/MASTER_PASSWORD environment variable is not set/, flash[:alert])
    end

    test "perform_master_password_reset requires admin access" do
      sign_out
      sign_in_as(@user)

      ENV["MASTER_PASSWORD"] = "CorrectMasterPass1!"

      patch perform_master_password_reset_admin_user_path(@user), params: {
        master_password: "CorrectMasterPass1!",
        new_password: "NewPassword99!",
        new_password_confirmation: "NewPassword99!"
      }

      assert_redirected_to root_path
    end
  end
end
