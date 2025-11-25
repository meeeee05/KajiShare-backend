module Api
  module V1
    class EvaluationsController < ApplicationController
      #レコード個別取得
      before_action :set_evaluation, only: [:show, :update]

      # GET /api/v1/evaluations
      def index
        evaluations = Evaluation.all
        render json: evaluations
      end

      # GET /api/v1/evaluations/:id
      def show
        render json: @evaluation
      end

      # POST /api/v1/evaluations
      def create
        evaluation = Evaluation.new(evaluation_params)

        if evaluation.save
          render json: evaluation, status: :created
        else
          render json: { errors: evaluation.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/evaluations/:id
      def update
        if @evaluation.update(evaluation_params)
          render json: @evaluation
        else
          render json: { errors: @evaluation.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_evaluation
        @evaluation = Evaluation.find(params[:id])
      end

      #データの生合成を保持
      #assignment_id
      #evaluator_id
      #score
      #feedback
      def evaluation_params
        params.require(:evaluation).permit(:assignment_id, :evaluator_id, :score, :feedback)
      end
    end
  end
end