class CallsController < ApplicationController
  def create
    numbers = Storage.load_numbers
    number = params[:phone_number].presence || numbers.sample

    begin
      call = TwilioService.make_call(number)
      render json: { 
        message: 'Call initiated successfully',
        call_sid: call.sid,
        status: call.status,
        to: number
      }
    rescue => e
      render json: { error: e.message }, status: :unprocessable_entity
    end
  end

  def logs
    logs = Storage.load_call_logs
    render json: { logs: logs }
  end
end