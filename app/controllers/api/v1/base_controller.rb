class Api::V1::BaseController < ApplicationController
  # 共通のエラーハンドリング
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

  private

  def record_not_found(error)
    render json: { error: error.message }, status: :not_found
  end

  def record_invalid(error)
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end

  #成功時共通
  def render_success(data = {}, message = nil)
    response = { success: true }
    response[:message] = message if message
    response[:data] = data unless data.empty?
    render json: response
  end
end
