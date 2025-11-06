class TwilioService
  class << self
    def client
      @client ||= Twilio::REST::Client.new(
        ENV['TWILIO_ACCOUNT_SID'],
        ENV['TWILIO_AUTH_TOKEN']
      )
    end

    def make_call(to_number)
      settings = VoiceSettings.load_settings
      voice_info = VoiceSettings.available_voices[settings['voice']]
      
      # Create TwiML inline
      twiml = Twilio::TwiML::VoiceResponse.new do |r|
        r.say(
          message: settings['message'],
          voice: settings['voice'],
          language: voice_info[:language]
        )
        r.pause(length: 1)
        r.say(
          message: settings['closing'],
          voice: settings['voice'],
          language: voice_info[:language]
        )
      end

      call = client.calls.create(
        twiml: twiml.to_s,
        to: to_number,
        from: ENV['TWILIO_PHONE_NUMBER'],
        status_callback: "#{ENV['APP_URL'] || 'http://localhost:3000'}/twilio/status",
        status_callback_event: ['completed', 'answered', 'busy', 'no-answer', 'failed'],
        status_callback_method: 'POST'
      )

      Storage.save_call_log({
        phone_number: to_number,
        call_sid: call.sid,
        status: call.status,
        timestamp: Time.current.iso8601
      })

      call
    rescue Twilio::REST::RestError => e
      Storage.save_call_log({
        phone_number: to_number,
        error: e.message,
        status: 'failed',
        timestamp: Time.current.iso8601
      })
      raise e
    end
  end
end