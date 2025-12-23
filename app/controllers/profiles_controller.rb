# frozen_string_literal: true

class ProfilesController < ApplicationController
  def show
    @user = Current.user
    @stats = {
      total_requests: @user.requests.count,
      completed_requests: @user.requests.completed.count,
      pending_requests: @user.requests.pending.count
    }
  end

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(profile_params)
      redirect_to profile_path, notice: "Profile updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def password
    @user = Current.user
  end

  def update_password
    @user = Current.user

    unless @user.authenticate(params[:current_password])
      @user.errors.add(:current_password, "is incorrect")
      return render :password, status: :unprocessable_entity
    end

    if @user.update(password_params)
      @user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to profile_path, notice: "Password changed successfully."
    else
      render :password, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
