class VoiceCommandsController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false
  
  def process_voice
    Rails.logger.info "Received voice command request: #{request.method}"
    
    case request.method
    when 'GET'
      # Return API key debug info
      api_key_present = ENV['OPENAI_API_KEY'].present?
      api_key_info = if api_key_present
        key = ENV['OPENAI_API_KEY']
        {
          present: true,
          length: key.length,
          starts_with: key[0..10],
          ends_with: key[-10..]
        }
      else
        { present: false }
      end
      
      render json: { 
        status: 'ready', 
        message: 'Voice command endpoint is ready to accept audio files',
        openai_api_key: api_key_info
      }
    when 'OPTIONS'
      head :ok
    when 'POST'
      handle_voice_upload
    else
      render json: { error: "Method not allowed" }, status: :method_not_allowed
    end
  end

  private

  def handle_voice_upload
    Rails.logger.info "Processing voice upload"
    Rails.logger.info "Params: #{params.inspect}"
    
    # Debug: Check what API key is loaded
    Rails.logger.info "=== ENVIRONMENT VARIABLE DEBUG ==="
    Rails.logger.info "OPENAI_API_KEY present: #{ENV['OPENAI_API_KEY'].present?}"
    if ENV['OPENAI_API_KEY'].present?
      key = ENV['OPENAI_API_KEY']
      Rails.logger.info "API Key length: #{key.length}"
      Rails.logger.info "API Key starts with: #{key[0..10]}"
      Rails.logger.info "API Key ends with: #{key[-10..]}"
    end
    Rails.logger.info "==================================="

    unless params[:audio].present?
      Rails.logger.error "No audio file provided"
      render json: { error: "No audio file provided" }, status: :bad_request
      return
    end

    begin
      unless ENV['OPENAI_API_KEY'].present?
        Rails.logger.error "OpenAI API key not configured"
        render json: { error: "OpenAI API key is not configured" }, 
               status: :unauthorized
        return
      end

      # Log the API key (first and last 4 chars only for security)
      api_key = ENV['OPENAI_API_KEY']
      masked_key = "#{api_key[0..7]}...#{api_key[-4..]}"
      Rails.logger.info "Using OpenAI API key: #{masked_key}"

      # Create a unique filename
      timestamp = Time.now.to_i
      # Get the content type and determine file extension
      content_type = params[:audio].content_type
      extension = case content_type
                  when /webm/ then 'webm'
                  when /wav/ then 'wav'
                  when /mp3/ then 'mp3'
                  when /ogg/ then 'ogg'
                  else 'webm'
                  end
      filename = "voice_command_#{timestamp}.#{extension}"
      audio_path = File.join(Dir.tmpdir, filename)
      Rails.logger.info "Using temp file: #{audio_path} (Content-Type: #{content_type})"

      begin
        # Save the uploaded audio file temporarily
        File.open(audio_path, 'wb') do |file|
          file.write(params[:audio].read)
        end
        Rails.logger.info "Audio file saved successfully"

        # Verify the file exists and is readable
        unless File.exist?(audio_path) && File.readable?(audio_path)
          raise "Audio file not accessible after saving"
        end

        # Initialize OpenAI client
        client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
        Rails.logger.info "OpenAI client initialized"
        
        # Log file size for debugging
        file_size = File.size(audio_path)
        Rails.logger.info "Audio file size: #{file_size} bytes"

        # Send audio to OpenAI Whisper API
        # Open file in a block to ensure it's properly closed
        audio_file = nil
        begin
          audio_file = File.open(audio_path, "rb")
          response = client.audio.transcribe(
            parameters: {
              model: "whisper-1",
              file: audio_file
            }
          )
        ensure
          audio_file&.close
        end

        # Get the transcribed text
        command = response.dig("text")
        Rails.logger.info "Transcribed text: #{command}"

        # Process the command (but don't execute it - just return transcription for dashboard)
        # The dashboard will send it to the chat AI
        
        render json: {
          transcription: command,
          transcribed_text: command,  # Keep both for compatibility
          success: true
        }
      rescue => e
        Rails.logger.error "Error in transcription: #{e.message}"
        raise
      ensure
        # Clean up the temporary file with better error handling
        begin
          File.delete(audio_path) if audio_path && File.exist?(audio_path)
        rescue => cleanup_error
          Rails.logger.warn "Could not delete temp file: #{cleanup_error.message}"
        end
      end
    rescue OpenAI::Error => e
      Rails.logger.error "OpenAI Error: #{e.message}"
      render json: { error: "Speech recognition failed: #{e.message}" }, 
             status: :service_unavailable
    rescue StandardError => e
      Rails.logger.error "Error processing voice command: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Failed to process voice command: #{e.message}" }, 
             status: :internal_server_error
    end
  end

  def process_voice_command(command)
    Rails.logger.info "=== PROCESSING VOICE COMMAND ==="
    Rails.logger.info "Command: #{command}"
    
    # Extract phone number from voice command
    if command.downcase.include?("call") || command.downcase.include?("dial")
      Rails.logger.info "Command contains 'call' or 'dial'"
      
      # Replace "plus" with "+" for voice transcription
      normalized_command = command.gsub(/\bplus\b/i, '+')
      Rails.logger.info "Normalized command: #{normalized_command}"
      
      # Try to extract phone number (with or without +)
      number = normalized_command.scan(/\+?\d[\d\s-]{9,}/).first&.gsub(/[\s-]/, '')
      Rails.logger.info "Extracted number: #{number.inspect}"
      
      return { error: "No phone number found in command" } unless number

      begin
        Rails.logger.info "Attempting to call: #{number}"
        call = TwilioService.make_call(number)
        Rails.logger.info "Call initiated successfully. SID: #{call.sid}"
        { success: true, message: "Calling #{number}", call_sid: call.sid }
      rescue => e
        Rails.logger.error "Failed to make call: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        { error: "Failed to make call: #{e.message}" }
      end
    else
      Rails.logger.warn "Command not recognized: #{command}"
      { error: "Command not recognized. Please say 'call' followed by a phone number." }
    end
  end
end