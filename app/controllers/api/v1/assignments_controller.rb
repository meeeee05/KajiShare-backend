module Api
  module V1
    class AssignmentsController < ApplicationController
      before_action :set_assignment, only: [:show]

      # GET /api/v1/assignments
      def index
        @assignments = Assignment.all
        render json: @assignments
      end

      # GET /api/v1/assignments/:id
      def show
        render json: @assignment
      end

      # POST /api/v1/tasks/:task_id/assignments（将来ネストさせる想定があるなら）
      def create
        @assignment = Assignment.new(assignment_params)

        if @assignment.save
          render json: @assignment, status: :created
        else
          render json: { errors: @assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/assignments/:id
      def update
        @assignment = Assignment.find(params[:id])

        if @assignment.update(assignment_params)
          render json: @assignment
        else
          render json: { errors: @assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/assignments/:id
      def destroy
        @assignment = Assignment.find(params[:id])
        @assignment.destroy

        head :no_content
      end

      private

      def set_assignment
        @assignment = Assignment.find(params[:id])
      end

      # Strong Parameters
      # 現在の assignment テーブル構造に合わせています
      def assignment_params
        params.require(:assignment).permit(
          :task_id,
          :assigned_to_id,
          :assigned_by_id,
          :due_date,
          :completed_date,
          :comment,
          :status
        )
      end
    end
  end
end