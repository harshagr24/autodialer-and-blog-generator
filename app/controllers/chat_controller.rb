class ChatController < ApplicationController
  def process_command
    command = params[:command]
    
    response = case analyze_intent(command)
    when :make_call
      handle_call_command(command)
    when :start_queue
      handle_queue_command(command)
    when :upload_numbers
      handle_upload_command(command)
    when :show_logs
      handle_logs_command(command)
    else
      { error: "I'm not sure how to handle that command. Try asking me to make calls, start calling all numbers, upload numbers, or show logs." }
    end

    render json: response
  end

  private

  def analyze_intent(command)
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    
    # Create a system prompt that defines the possible intents
    messages = [
      { role: "system", content: "You are an autodialer assistant. Analyze the user command and respond ONLY with one of these intents: make_call, start_queue, upload_numbers, show_logs, unknown. Use 'start_queue' for commands about calling all numbers or bulk calling. Nothing else." },
      { role: "user", content: command }
    ]

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: messages,
        temperature: 0.1
      }
    )

    intent = response.dig("choices", 0, "message", "content").strip.downcase
    intent = :unknown unless [:make_call, :start_queue, :upload_numbers, :show_logs].include?(intent.to_sym)
    intent.to_sym
  end

  def extract_phone_number(command)
    # Extract numbers that look like phone numbers
    numbers = command.scan(/\+?\d{10,}/).first
    return numbers if numbers

    # If no direct number found, ask OpenAI to extract it
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
    messages = [
      { role: "system", content: "Extract only the phone number from the text. Respond with ONLY the number in +91XXXXXXXXXX format. If no valid Indian phone number is found, respond with 'none'." },
      { role: "user", content: command }
    ]

    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: messages,
        temperature: 0.1
      }
    )

    number = response.dig("choices", 0, "message", "content").strip
    number == 'none' ? nil : number
  end

  def handle_call_command(command)
    number = extract_phone_number(command)
    return { error: "No valid phone number found in the command" } unless number

    begin
      call = TwilioService.make_call(number)
      { success: true, message: "Calling #{number}", call_sid: call.sid }
    rescue => e
      { error: "Failed to make call: #{e.message}" }
    end
  end

  def handle_upload_command(command)
    numbers = command.scan(/\+?\d{10,}/)
    
    if numbers.any?
      Storage.save_numbers(numbers)
      { success: true, message: "Added #{numbers.length} numbers to the database" }
    else
      { error: "No valid phone numbers found in the command" }
    end
  end

  def handle_logs_command(command)
    logs = Storage.load_call_logs
    total = logs.length
    success = logs.count { |log| log['status'] == 'completed' }
    failed = logs.count { |log| log['status'] == 'failed' }
    in_progress = logs.count { |log| ['queued', 'ringing', 'in-progress'].include?(log['status']) }

    {
      success: true,
      summary: {
        total_calls: total,
        successful_calls: success,
        failed_calls: failed,
        in_progress_calls: in_progress
      },
      recent_logs: logs.last(5)
    }
  end

  def handle_queue_command(command)
    numbers = Storage.load_numbers
    
    if numbers.empty?
      return { error: "No phone numbers loaded. Please upload numbers first or generate test numbers." }
    end

    # Start the call queue
    CallQueueJob.perform_later(numbers)
    
    { success: true, message: "Started calling #{numbers.length} numbers automatically. Check the logs for progress." }
  end
end