module Admin
  class UsersController < BaseController
    before_action :set_user, only: [:show, :edit, :update, :destroy, :master_password_reset, :perform_master_password_reset]

    def index
      @users = User.active.order(created_at: :desc)
    end

    def show
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "User was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      update_params = user_params
      update_params = update_params.except(:password, :password_confirmation) if update_params[:password].blank?

      if @user.update(update_params)
        redirect_to admin_users_path, notice: "User was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == Current.user
        redirect_to admin_users_path, alert: "You cannot delete yourself."
      else
        @user.soft_delete!
        redirect_to admin_users_path, notice: "User was successfully deleted."
      end
    end

    def master_password_reset
    end

    def perform_master_password_reset
      master_password = master_reset_params[:master_password]
      new_password = master_reset_params[:new_password]
      new_password_confirmation = master_reset_params[:new_password_confirmation]

      if User.reset_password_with_master!(@user, master_password, new_password, new_password_confirmation)
        redirect_to admin_users_path, notice: "Password for #{@user.username} was successfully reset."
      else
        if ENV["MASTER_PASSWORD"].blank?
          flash.now[:alert] = "Master password reset is not configured (MASTER_PASSWORD environment variable is not set)."
        elsif @user.errors.any?
          flash.now[:alert] = @user.errors.full_messages.join(", ")
        else
          flash.now[:alert] = "Invalid master password."
        end
        render :master_password_reset, status: :unprocessable_entity
      end
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:name, :username, :password, :password_confirmation, :role)
    end

    def master_reset_params
      params.permit(:master_password, :new_password, :new_password_confirmation)
    end
  end
end
