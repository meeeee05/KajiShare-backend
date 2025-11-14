module Api
  module V1
    class TasksController < ApplicationController
      before_action :set_group, only: [:create]  # createのみgroup必須
      before_action :set_task, only: [:show, :update, :destroy]

      # GET /api/v1/tasks - 全タスク一覧（独立ルート用）
      def index
        if params[:group_id].present?
          # グループ内のタスク一覧
          @group = Group.find(params[:group_id])
          tasks = @group.tasks
        else
          # 全タスク一覧
          tasks = Task.all
        end
        render json: tasks
      end

      # POST /api/v1/groups/:group_id/tasks
      def create
        task = @group.tasks.new(task_params)
        if task.save
          render json: task, status: :created
        else
          render json: { errors: task.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # GET /api/v1/tasks/:id
      def show
        render json: @task
      end

      # PUT/PATCH /api/v1/tasks/:id
      def update
        if @task.update(task_params)
          render json: @task
        else
          render json: { errors: @task.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tasks/:id
      def destroy
        @task.destroy
        head :no_content
      end

      private

      def set_group
        @group = Group.find(params[:group_id])
      end

      def set_task
        @task = Task.find(params[:id])
      end

      def task_params
        params.require(:task).permit(:name, :description, :point)
      end
    end
  end
end