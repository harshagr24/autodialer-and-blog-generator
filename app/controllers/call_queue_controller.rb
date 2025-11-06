class CallQueueController < ApplicationController
  @@calling_thread = nil
  @@stop_calling = false
  @@current_call_index = 0
  @@total_numbers = 0

  def start
    numbers = Storage.load_numbers
    
    if numbers.empty?
      render json: { error: 'No phone numbers loaded. Please upload numbers first.' }, status: :bad_request
      return
    end

    # Check if already calling
    if @@calling_thread&.alive?
      render json: { error: 'Call queue is already running' }, status: :bad_request
      return
    end

    # Reset flags
    @@stop_calling = false
    @@current_call_index = 0
    @@total_numbers = numbers.length

    # Start calling in a thread - ONE BY ONE with proper waiting
    @@calling_thread = Thread.new do
      numbers.each_with_index do |number, index|
        # Check if stop was requested
        if @@stop_calling
          Rails.logger.info "Call queue stopped by user"
          break
        end

        @@current_call_index = index + 1
        Rails.logger.info "Calling #{@@current_call_index}/#{@@total_numbers}: #{number}"
        
        begin
          call = TwilioService.make_call(number)
          Rails.logger.info "Call initiated: #{call.sid}"
          
          # WAIT FOR CALL TO COMPLETE before next call
          # Poll the call status until it's finished
          wait_for_call_completion(call.sid, number)
          
        rescue => e
          Rails.logger.error "Failed to call #{number}: #{e.message}"
          # Wait a bit before trying next number even on error
          sleep(2)
        end
      end
      
      @@current_call_index = 0
      Rails.logger.info "Call queue completed"
    end
    
    render json: { 
      message: "Started calling #{numbers.length} numbers sequentially",
      total_numbers: numbers.length
    }
  end

  def status
    logs = Storage.load_call_logs
    
    stats = {
      total: logs.length,
      completed: logs.count { |l| l['status'] == 'completed' },
      busy: logs.count { |l| l['status'] == 'busy' },
      no_answer: logs.count { |l| l['status'] == 'no-answer' },
      failed: logs.count { |l| l['status'] == 'failed' || l['error'] },
      in_progress: logs.count { |l| ['queued', 'ringing', 'in-progress'].include?(l['status']) }
    }
    
    render json: {
      statistics: stats,
      recent_calls: logs.last(20).reverse,
      queue_status: {
        is_running: @@calling_thread&.alive? || false,
        current_call: @@current_call_index,
        total_numbers: @@total_numbers
      }
    }
  end

  def stop
    @@stop_calling = true
    
    # Wait a moment for the thread to notice
    sleep(0.5)
    
    render json: { 
      message: 'Call queue stopped',
      stopped_at: @@current_call_index,
      total_numbers: @@total_numbers
    }
  end

  private

  def wait_for_call_completion(call_sid, phone_number)
    max_wait_time = 90 # Maximum 90 seconds per call (more realistic)
    check_interval = 3 # Check every 3 seconds (reduce API calls)
    elapsed_time = 0
    
    Rails.logger.info "Waiting for call #{call_sid} to complete..."
    
    # Give the call a moment to start
    sleep(2)
    
    loop do
      # Check if stop was requested
      if @@stop_calling
        Rails.logger.info "Stop requested, canceling call..."
        # Try to cancel the ongoing call
        begin
          client = Twilio::REST::Client.new(
            ENV['TWILIO_ACCOUNT_SID'],
            ENV['TWILIO_AUTH_TOKEN']
          )
          client.calls(call_sid).update(status: 'canceled')
        rescue => e
          Rails.logger.error "Could not cancel call: #{e.message}"
        end
        break
      end
      
      # Check call status
      begin
        client = Twilio::REST::Client.new(
          ENV['TWILIO_ACCOUNT_SID'],
          ENV['TWILIO_AUTH_TOKEN']
        )
        call = client.calls(call_sid).fetch
        status = call.status
        duration = call.duration.to_i if call.duration
        
        Rails.logger.info "Call #{call_sid} status: #{status}, duration: #{duration || 0}s, elapsed: #{elapsed_time}s"
        
        # Call is finished if it's in any of these states
        if ['completed', 'busy', 'no-answer', 'failed', 'canceled'].include?(status)
          Rails.logger.info "✓ Call completed with status: #{status}"
          
          # Update the call log with final status
          Storage.save_call_log({
            phone_number: phone_number,
            call_sid: call_sid,
            status: status,
            duration: duration,
            timestamp: Time.current.iso8601
          })
          
          break
        end
        
        # If call is still in progress states, keep waiting
        # States: queued -> ringing -> in-progress -> completed
        
      rescue => e
        Rails.logger.error "Error checking call status: #{e.message}"
        # If we can't check status, assume it failed and move on
        break
      end
      
      # Check timeout
      if elapsed_time >= max_wait_time
        Rails.logger.warn "⚠️ Call timeout after #{max_wait_time} seconds, moving to next..."
        break
      end
      
      # Wait before next check
      sleep(check_interval)
      elapsed_time += check_interval
    end
    
    Rails.logger.info "Moving to next call..."
    sleep(2) # Brief pause between calls
  end
end
