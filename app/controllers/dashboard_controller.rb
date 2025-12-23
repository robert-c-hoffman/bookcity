class DashboardController < ApplicationController
  def index
    @pending_requests = Current.user.admin? ? Request.active.count : Request.for_user(Current.user).active.count
    @completed_requests = Current.user.admin? ? Request.completed.count : Request.for_user(Current.user).completed.count
    @active_downloads = Download.active.count
    @system_health = SystemHealth.all.index_by(&:service)
  end
end
