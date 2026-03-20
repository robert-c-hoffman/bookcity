require "test_helper"

module Admin
  class UsersControllerMasterResetTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:two)
      @user = users(:one)
      sign_in_as(@admin)
    end

    test "master_password_reset page renders successfully" do
      get master_password_reset_admin_user_path(@user)
      assert_response :success
    end

    test "perform_master_password_reset resets password without master password" do
      new_password = "NewPassword99!"

      patch perform_master_password_reset_admin_user_path(@user), params: {
        new_password: new_password,
        new_password_confirmation: new_password
      }

      assert_redirected_to admin_users_path
      assert_match(/Password for #{@user.username} was successfully reset/, flash[:notice])
      assert @user.reload.authenticate(new_password)
    end

    test "perform_master_password_reset fails with invalid new password" do
      patch perform_master_password_reset_admin_user_path(@user), params: {
        new_password: "short",
        new_password_confirmation: "short"
      }

      assert_response :unprocessable_entity
    end

    test "perform_master_password_reset requires admin access" do
      sign_out
      sign_in_as(@user)

      patch perform_master_password_reset_admin_user_path(@user), params: {
        new_password: "NewPassword99!",
        new_password_confirmation: "NewPassword99!"
      }

      assert_redirected_to root_path
    end
  end
end
