class PhoneNumbersController < ApplicationController
  def index
    @numbers = Storage.load_numbers
    render json: { numbers: @numbers }
  end

  def create
    numbers = params[:numbers].to_s.split(/[\n,]/).map(&:strip).reject(&:empty?)
    Storage.save_numbers(numbers)
    render json: { message: 'Numbers saved successfully', count: numbers.length }
  end
end