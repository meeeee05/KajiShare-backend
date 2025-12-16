module Api
  module V1
    class EvaluationsController < ApplicationController
      #レコード個別取得
      before_action :set_evaluation, only: [:show, :update, :destroy]
      before_action :authenticate_user!  # ログイン済みかどうか
      before_action :check_member_permission, only: [:index, :show, :create, :update]  # 参照・作成・更新はMember権限以上
      before_action :check_admin_permission, only: [:destroy]  # 削除はAdmin権限のみ

      # GET /api/v1/evaluations
      def index
        # 認証確認
        unless current_user
          handle_unauthorized("Authentication required to view evaluations")
          return
        end

        evaluations = Evaluation.all
        render json: evaluations, each_serializer: EvaluationSerializer
      end

      # GET /api/v1/evaluations/:id
      def show
        # 認証確認
        unless current_user
          handle_unauthorized("Authentication required to view evaluation details")
          return
        end

        render json: @evaluation, serializer: EvaluationSerializer, current_user: current_user
      end

      # POST /api/v1/evaluations
      def create
        # 認証確認
        unless current_user
          handle_unauthorized("Authentication required to create evaluations")
          return
        end

        begin
          evaluation = Evaluation.new(evaluation_params)

          # DBに保存
          if evaluation.save
            render json: evaluation, serializer: EvaluationSerializer, current_user: current_user, status: :created
          else
            handle_unprocessable_entity(evaluation.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to create evaluation: #{e.message}")
        end
      end

      # PATCH/PUT /api/v1/evaluations/:id
      def update
        # 認証確認
        unless current_user
          handle_unauthorized("Authentication required to update evaluations")
          return
        end

        begin
          if @evaluation.update(evaluation_params)
            render json: @evaluation, serializer: EvaluationSerializer, current_user: current_user
          else
            handle_unprocessable_entity(@evaluation.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to update evaluation: #{e.message}")
        end
      end

      # DELETE /api/v1/evaluations/:id - Admin権限が必要
      def destroy
        # 認証確認
        unless current_user
          handle_unauthorized("Authentication required to delete evaluations")
          return
        end

        begin
          #トランザクション内で安全に削除
          ActiveRecord::Base.transaction do
            # 削除ログ記録
            Rails.logger.info "Deleting evaluation (ID: #{@evaluation.id}) for Assignment #{@evaluation.assignment_id} by admin user #{current_user.name}"
            
            #評価を削除
            @evaluation.destroy!
            
            render json: { 
              message: "Evaluation has been successfully deleted",
              deleted_at: Time.current 
            }, status: :ok
          end
        rescue => e
          Rails.logger.error "Failed to delete evaluation: #{e.message}"
          handle_unprocessable_entity(["Failed to delete evaluation: #{e.message}"])
        end
      end

      private

      def set_evaluation
        @evaluation = Evaluation.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        handle_not_found("Evaluation with ID #{params[:id]} not found")
      end

      #以下4つだけを取り出す、悪意あるデータは除外
      #assignment_id
      #evaluator_id
      #score
      #feedback
      def evaluation_params
        params.require(:evaluation).permit(:assignment_id, :evaluator_id, :score, :feedback)
      end

      # Member権限チェック：指定されたグループのmember以上の権限のみ操作可能
      def check_member_permission
        # current_userが存在しない場合（認証失敗）
        unless current_user
          handle_unauthorized("Authentication required to access evaluation information")
          return
        end

        # group_idの取得（アクションごとに取得）
        case action_name
        when 'index'
          # 全評価一覧は現在のユーザーがメンバーのグループの評価のみ
          return  # indexは後で改修
        when 'create'
          assignment = Assignment.find(evaluation_params[:assignment_id])
          group_id = assignment.task.group_id
        when 'show', 'update'
          group_id = @evaluation.assignment.task.group_id
        end
        
        membership = Membership.find_by(user_id: current_user.id, group_id: group_id)

        # メンバー存在チェック
        if membership.nil?
          handle_forbidden("You are not a member of this group")
          return
        end

        # アクティブメンバーチェック
        unless membership.active?
          handle_forbidden("Your membership is not active")
        end
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        # current_userが存在しない場合（認証失敗）
        unless current_user
          handle_unauthorized("Authentication required for admin operations")
          return
        end

        # group_idの取得
        group_id = @evaluation.assignment.task.group_id
        
        membership = Membership.find_by(user_id: current_user.id, group_id: group_id)

        # メンバー存在チェック
        if membership.nil?
          handle_forbidden("You are not a member of this group")
          return
        end

        # Admin権限チェック
        if membership.role != "admin"
          handle_forbidden("You are not allowed to perform this action. Admin permission required.")
        end
      end
    end
  end
end