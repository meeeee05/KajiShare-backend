# app/controllers/api/v1/assignments_controller.rb

module Api
  module V1
    class AssignmentsController < ApplicationController
      before_action :set_task, only: [:index, :create]
      before_action :set_assignment, only: [:show, :update, :destroy]

      # GET /api/v1/tasks/:task_id/assignments
      def index
        assignments = @task.assignments
        render json: assignments
      end

      # POST /api/v1/tasks/:task_id/assignments
      def create
        assignment = @task.assignments.build(assignment_params)

        if assignment.save
          render json: assignment, status: :created
        else
          render json: { errors: assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/assignments/:id
      def show
        render json: @assignment
      end

      # PATCH/PUT /api/v1/assignments/:id
      def update
        if @assignment.update(assignment_params)
          render json: @assignment
        else
          render json: { errors: @assignment.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/assignments/:id
      def destroy
        @assignment.destroy
        head :no_content
      end

      private

      def set_task
        @task = Task.find(params[:task_id])
      end

      def set_assignment
        @assignment = Assignment.find(params[:id])
      end

      def assignment_params
        params.require(:assignment).permit(
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