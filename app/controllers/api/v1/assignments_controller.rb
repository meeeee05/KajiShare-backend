# app/controllers/api/v1/assignments_controller.rb
module Api
  module V1
    class AssignmentsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_task, only: [:index, :create]
      before_action :set_assignment, only: [:show, :update, :destroy]
      before_action :validate_permission  
      
      # GET /api/v1/tasks/:task_id/assignments
      def index
        assignments = @task.assignments.order(:due_date)
        render json: assignments, each_serializer: AssignmentSerializer
      end

      # GET /api/v1/assignments/:id
      def show
        render_assignment_success(@assignment)
      end


      # POST /api/v1/tasks/:task_id/assignments - Member権限以上が必要
      def create
        begin
          assignment = @task.assignments.build(assignment_params)
          
          # 現在のユーザーのmembership_idを設定
          membership = get_current_user_membership(@task.group_id)
          assignment.membership_id = membership.id if membership

          if assignment.save
            Rails.logger.info "Assignment created: (ID: #{assignment.id}) for Task '#{@task.name}' by user #{current_user.name}"
            render_assignment_success(assignment, :created)
          else
            handle_unprocessable_entity(assignment.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to create assignment: #{e.message}")
        end
      end

      # PATCH/PUT /api/v1/assignments/:id - Member権限以上が必要
      def update
        begin
          if @assignment.update(assignment_params)
            Rails.logger.info "Assignment updated: (ID: #{@assignment.id}) for Task '#{@assignment.task.name}' by user #{current_user.name}"
            render_assignment_success(@assignment)
          else
            handle_unprocessable_entity(@assignment.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to update assignment: #{e.message}")
        end
      end

      # DELETE /api/v1/assignments/:id - Admin権限が必要
      def destroy
        begin
          ActiveRecord::Base.transaction do
            Rails.logger.info "Deleting assignment (ID: #{@assignment.id}) from Task '#{@assignment.task.name}' by admin user #{current_user.name}"
            
            @assignment.destroy!
            
            render json: { 
              message: "Assignment has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue StandardError => e
          handle_internal_error("Failed to delete assignment: #{e.message}")
        end
      end

      private

      def set_task
        @task = Task.find(params[:task_id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("Task with ID #{params[:task_id]} not found")
      end

      def set_assignment
        @assignment = Assignment.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("Assignment with ID #{params[:id]} not found")
      end
      
      # Strong Parameters(以下パラメータを受け入れ)
      def assignment_params
        params.require(:assignment).permit(:due_date, :completed_date, :comment)
      end
      
      # 権限チェック
      def validate_permission
        group_id, required_role = case action_name
        when 'index', 'create'
          [@task.group_id, 'member']
        when 'show', 'update'
          [@assignment.task.group_id, 'member']
        when 'destroy'
          [@assignment.task.group_id, 'admin']
        end

        membership = get_current_user_membership(group_id)
        validate_membership(membership, required_role)
      end

      # 権限取得とエラーハンドリング
      def get_current_user_membership(group_id)
        current_user.memberships.find_by(group_id: group_id, active: true)
      end

      # 権限検証
      def validate_membership(membership, required_role = 'member')
        return handle_forbidden("You are not a member of this group") if membership.nil?
        
        if required_role == 'admin' && !membership.admin?
          return handle_forbidden("You are not allowed to perform this action. Admin permission required.")
        end
      end

      # 共通メソッド：アサインメント情報のJSONレスポンスを生成
      def render_assignment_success(assignment, status = :ok)
        render json: assignment, serializer: AssignmentSerializer, status: status
      end
    end
  end
end