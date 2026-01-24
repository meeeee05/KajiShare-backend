module Api
  module V1
    class EvaluationsController < ApplicationController
      before_action :authenticate_user!
      before_action :set_evaluation, only: [:show, :update, :destroy]
      before_action :validate_permission

      # GET /api/v1/evaluations
      def index
        # 現在のユーザーが参加しているグループの評価のみ取得
        user_group_ids = current_user.memberships.where(active: true).pluck(:group_id)
        evaluations = Evaluation.joins(assignment: { task: :group })
                               .where(tasks: { group_id: user_group_ids })
        render json: evaluations, each_serializer: EvaluationSerializer
      end

      # GET /api/v1/evaluations/:id
      def show
        render_evaluation_success(@evaluation)
      end

      # POST /api/v1/evaluations
      def create
        begin
          evaluation = Evaluation.new(evaluation_params)
          # 現在のユーザーを評価者として設定
          evaluation.evaluator_id = current_user.id  

          if evaluation.save
            Rails.logger.info "Evaluation created: (ID: #{evaluation.id}) for Assignment #{evaluation.assignment_id} by user #{current_user.name}"
            render_evaluation_success(evaluation, :created)
          else
            handle_unprocessable_entity(evaluation.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to create evaluation: #{e.message}")
        end
      end

      # PATCH/PUT /api/v1/evaluations/:id
      def update
        begin
          if @evaluation.update(evaluation_params)
            Rails.logger.info "Evaluation updated: (ID: #{@evaluation.id}) for Assignment #{@evaluation.assignment_id} by user #{current_user.name}"
            render_evaluation_success(@evaluation)
          else
            handle_unprocessable_entity(@evaluation.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to update evaluation: #{e.message}")
        end
      end

      # DELETE /api/v1/evaluations/:id - Admin権限が必要
      def destroy
        begin
          ActiveRecord::Base.transaction do
            Rails.logger.info "Deleting evaluation (ID: #{@evaluation.id}) for Assignment #{@evaluation.assignment_id} by admin user #{current_user.name}"
            
            @evaluation.destroy!
            
            render json: { 
              message: "Evaluation has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue StandardError => e
          handle_internal_error("Failed to delete evaluation: #{e.message}")
        end
      end

      private

      # 該当IDのレコードをDBから取得
      def set_evaluation
        @evaluation = Evaluation.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("Evaluation with ID #{params[:id]} not found")
      end

      # 以下カラムのみ表示・更新を許可
      def evaluation_params
        params.require(:evaluation).permit(:assignment_id, :score, :feedback)
      end

      # 権限チェック
      def validate_permission
        # indexアクションは結果フィルタリングで安全性を確保するため、権限チェック不要
        return if action_name == 'index'

        group_id, required_role = case action_name
        when 'create'
          assignment_id = evaluation_params[:assignment_id]
          if assignment_id.blank?
            return handle_unprocessable_entity(['Assignment must exist'])
          end
          begin
            assignment = Assignment.find(assignment_id)
          rescue ActiveRecord::RecordNotFound
            return handle_unprocessable_entity(["Assignment must exist"])
          end
          [assignment.task.group_id, 'member']
        when 'show', 'update'
          [@evaluation.assignment.task.group_id, 'member']
        when 'destroy'
          [@evaluation.assignment.task.group_id, 'admin']
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

      # 共通メソッド：評価情報のJSONレスポンスを生成
      def render_evaluation_success(evaluation, status = :ok)
        render json: evaluation, serializer: EvaluationSerializer, current_user: current_user, status: status
      end
    end
  end
end