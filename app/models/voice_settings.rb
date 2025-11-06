class VoiceSettings
  class << self
    def available_voices
      {
        'alice' => { language: 'en-US', gender: 'female' },
        'man' => { language: 'en-US', gender: 'male' },
        'woman' => { language: 'en-US', gender: 'female' },
        'polly.joanna' => { language: 'en-US', gender: 'female' },
        'polly.matthew' => { language: 'en-US', gender: 'male' },
        'polly.aditi' => { language: 'hi-IN', gender: 'female' }, # Hindi voice
        'google.en-IN-Standard-C' => { language: 'en-IN', gender: 'female' }, # Indian English
        'google.hi-IN-Standard-C' => { language: 'hi-IN', gender: 'female' }  # Hindi
      }
    end

    def save_settings(settings)
      write_json('voice_settings.json', settings)
    end

    def load_settings
      read_json('voice_settings.json') || default_settings
    end

    def default_settings
      {
        'voice' => 'alice',
        'language' => 'en-US',
        'speed' => 1.0,
        'message' => 'Hello! This is a test call from your auto dialer application.',
        'closing' => 'Thank you for your time. Goodbye!'
      }
    end

    private

    def write_json(filename, data)
      FileUtils.mkdir_p(Storage::DATA_DIR) unless Dir.exist?(Storage::DATA_DIR)
      File.write(Storage::DATA_DIR.join(filename), JSON.pretty_generate(data))
    end

    def read_json(filename)
      file_path = Storage::DATA_DIR.join(filename)
      return nil unless File.exist?(file_path)
      JSON.parse(File.read(file_path))
    end
  end
end