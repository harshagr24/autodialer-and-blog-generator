class TwilioWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def call_status
    call_sid = params['CallSid']
    status = params['CallStatus']
    phone_number = params['To']
    
    Rails.logger.info "Twilio webhook: CallSid=#{call_sid}, Status=#{status}, To=#{phone_number}"
    
    # Update the call log with the new status
    logs = Storage.load_call_logs
    log_entry = logs.find { |log| log['call_sid'] == call_sid }
    
    if log_entry
      log_entry['status'] = status
      log_entry['updated_at'] = Time.current.iso8601
      Storage.save_call_logs(logs)
    end
    
    head :ok
  end
end
