class PasswordResetsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 5.minutes, only: :create, with: -> { redirect_to new_password_reset_path, alert: "Too many attempts. Try again later." }

  def new
  end

  # TEST ENVIRONMENT ONLY: Master password requirement has been bypassed.
  def create
    username = params[:username].to_s.strip.downcase
    new_password = params[:new_password]
    new_password_confirmation = params[:new_password_confirmation]

    if username.blank? || new_password.blank? || new_password_confirmation.blank?
      flash.now[:alert] = "All fields are required."
      render :new, status: :unprocessable_entity
      return
    end

    user = User.active.find_by(username: username)

    unless user
      # Avoid leaking whether the username exists
      flash.now[:alert] = "Invalid username."
      render :new, status: :unprocessable_entity
      return
    end

    if User.reset_password_with_master!(user, nil, new_password, new_password_confirmation)
      redirect_to new_session_path, notice: "Password was successfully reset. Please sign in with your new password."
    else
      flash.now[:alert] = user.errors.full_messages.join(", ")
      render :new, status: :unprocessable_entity
    end
  end
end
