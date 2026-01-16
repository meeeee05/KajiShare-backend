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
          handle_internal_error(e)
        end
      end

      private

      # 該当IDのレコードをDBから取得
      def set_evaluation
        @evaluation = Evaluation.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        handle_not_found("Evaluation with ID #{params[:id]} not found")
      end

      #以下4つだけを取り出す、悪意あるデータは除外（改ざんやなりすましを防ぐ）
      #assignment_id, evaluator_id, score, feedback
      def evaluation_params
        params.require(:evaluation).permit(:assignment_id, :evaluator_id, :score, :feedback)
      end

      # 現在のユーザーのメンバーシップ取得
      def current_user_membership(group_id)
        Membership.find_by(user_id: current_user.id, group_id: group_id)
      end

      # nilの場合や非アクティブの場合に403エラー
      def validate_membership(membership)
        return handle_forbidden("You are not a member of this group") if membership.nil?
        return handle_forbidden("Your membership is not active") unless membership.active?
        membership
      end

      # Member権限チェック：指定されたグループのmember以上の権限のみ操作可能
      def check_member_permission
        group_id = get_group_id_for_action
        return if group_id.nil? # indexアクションは既にフィルタリング済み
        
        membership = current_user_membership(group_id)
        validate_membership(membership)
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        group_id = @evaluation.assignment.task.group_id
        membership = current_user_membership(group_id)
        validate_membership(membership)

        return handle_forbidden("You are not allowed to perform this action. Admin permission required.") unless membership.admin?
      end

      # 権限チェックのためアクション別のgroup_id取得
      def get_group_id_for_action
        case action_name
        when 'index'
          # indexアクションでは権限チェックは行わない
          nil
        when 'create'
          assignment = Assignment.find(evaluation_params[:assignment_id])
          assignment.task.group_id
        when 'show', 'update'
          @evaluation.assignment.task.group_id
        end
      end

      # 共通メソッド：評価情報のJSONレスポンスを生成
      def render_evaluation_success(evaluation, status = :ok)
        render json: evaluation, serializer: EvaluationSerializer, current_user: current_user, status: status
      end
    end
  end
end