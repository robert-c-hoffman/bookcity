module Admin
  class SettingsController < BaseController
    def index
      @settings_by_category = SettingsService.all_by_category
    end

    def update
      key = params[:id]
      value = params[:setting][:value]

      SettingsService.set(key, value)

      respond_to do |format|
        format.html { redirect_to admin_settings_path, notice: "Setting updated." }
        format.turbo_stream
      end
    rescue ArgumentError => e
      redirect_to admin_settings_path, alert: e.message
    end

    def bulk_update
      params[:settings]&.each do |key, value|
        SettingsService.set(key, value)
      end

      redirect_to admin_settings_path, notice: "Settings updated successfully."
    rescue ArgumentError => e
      redirect_to admin_settings_path, alert: e.message
    end
  end
end
