class VoiceSettingsController < ApplicationController
  def show
    render json: {
      current_settings: VoiceSettings.load_settings,
      available_voices: VoiceSettings.available_voices
    }
  end

  def update
    settings = VoiceSettings.load_settings.merge(voice_params)
    VoiceSettings.save_settings(settings)
    render json: { settings: settings }
  end

  private

  def voice_params
    params.require(:settings).permit(:voice, :language, :speed, :message, :closing)
  end
end