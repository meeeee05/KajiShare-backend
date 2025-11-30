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

      # DELETE /api/v1/evaluations/:id - Admin権限が必要
      def destroy
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
          render json: { error: "Failed to delete evaluation: #{e.message}" }, status: :unprocessable_entity
        end
      end

      private

      def set_evaluation
        @evaluation = Evaluation.find(params[:id])
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
          render json: { error: "You are not a member of this group" }, status: :forbidden
          return
        end

        # アクティブメンバーチェック
        unless membership.active?
          render json: { error: "Your membership is not active" }, status: :forbidden
        end
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        # group_idの取得
        group_id = @evaluation.assignment.task.group_id
        
        membership = Membership.find_by(user_id: current_user.id, group_id: group_id)

        # メンバー存在チェック
        if membership.nil?
          render json: { error: "You are not a member of this group" }, status: :forbidden
          return
        end

        # Admin権限チェック
        if membership.role != "admin"
          render json: { error: "You are not allowed to perform this action. Admin permission required." }, status: :forbidden
        end
      end
    end
  end
end