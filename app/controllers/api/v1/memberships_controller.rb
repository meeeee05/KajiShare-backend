module Api
  module V1
    class MembershipsController < ApplicationController
      before_action :set_membership, only: [:show, :update, :destroy, :change_role]
      before_action :authenticate_user!  # 全アクションで認証
      before_action :check_member_permission, only: [:index, :show]  # 参照はメンバー権限以上
      before_action :check_admin_permission, only: [:create, :update, :destroy, :change_role]

      # GET /api/v1/memberships - 現在のユーザーが参加しているグループのメンバーシップのみ返す
      def index
        # クエリパラメータでgroup_idが指定された場合はそのグループのみ、未指定なら全ての参加グループを取得
        if params[:group_id].present?
          memberships = Membership.where(group_id: params[:group_id])
        else
          # 現在のユーザーが参加している全グループのメンバーシップを取得
          user_group_ids = current_user.memberships.where(active: true).pluck(:group_id)
          memberships = Membership.where(group_id: user_group_ids)
        end
        render json: memberships, each_serializer: MembershipSerializer
      end

      # GET /api/v1/memberships/:id - 同じグループのメンバーのみアクセス可能
      def show
        render_membership_success(@membership)
      end

      # POST /api/v1/memberships - Admin権限で新規メンバーシップ作成
      def create
        begin
          membership = Membership.new(membership_params)
          if membership.save
            Rails.logger.info "Membership created: User #{membership.user.name} joined Group #{membership.group.name} as #{membership.role} by admin #{current_user.name}"
            render_membership_success(membership, :created)
          else
            handle_unprocessable_entity(membership.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to create membership: #{e.message}")
        end
      end

      # PUT /api/v1/memberships/:id - Admin権限でメンバーシップ更新（roleは専用エンドポイントで変更）
      def update
        begin
          if @membership.update(membership_params)
            Rails.logger.info "Membership updated: User #{@membership.user.name} in Group #{@membership.group.name} by admin #{current_user.name}"
            render_membership_success(@membership)
          else
            handle_unprocessable_entity(@membership.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to update membership: #{e.message}")
        end
      end

      # DELETE /api/v1/memberships/:id - Admin権限でメンバーシップ削除
      def destroy
        # 最後のAdminチェック
        return unless ensure_not_last_admin(@membership, "delete the last admin of the group")

        # 削除ログ記録
        Rails.logger.info "Deleting membership: User #{@membership.user.name} from Group #{@membership.group.name} by admin #{current_user.name}"
        
        @membership.destroy
        head :no_content
      end

      # PATCH /api/v1/memberships/:id/change_role - Admin権限でロール変更専用エンドポイント
      # AdminからMemberへの変更時に、最後のAdminではないかを確認
      def change_role
        begin
          new_role = params[:role]
          
          unless ['admin', 'member'].include?(new_role)
            return handle_unprocessable_entity(["Invalid role. Must be 'admin' or 'member'"])
          end

          # 現在のロール（権限）と同じ場合は何もしない
          if @membership.role == new_role
            return render json: { message: "Role is already #{new_role}" }, status: :ok
          end

          # AdminからMemberに変更する場合の制限チェック
          if @membership.admin? && new_role == "member"
            return unless ensure_not_last_admin(@membership, "demote the last admin")
          end

          # ロール変更実行
          if @membership.update(role: new_role)
            Rails.logger.info "Role changed: User #{@membership.user.name} in Group #{@membership.group.name} from #{@membership.role_was} to #{new_role} by admin #{current_user.name}"
            render json: { 
              message: "Role successfully changed to #{new_role}"
            }, status: :ok
          else
            handle_unprocessable_entity(@membership.errors.full_messages)
          end
        rescue StandardError => e
          handle_internal_error("Failed to change role: #{e.message}")
        end
      end

      private

      def set_membership
        @membership = Membership.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        handle_not_found("Membership with ID #{params[:id]} not found")
      end

      # 通常の更新用パラメータ（roleは専用エンドポイントで変更）
      def membership_params
        # roleの変更は専用のchange_roleエンドポイントでのみ可能
        params.require(:membership).permit(:user_id, :group_id, :workload_ratio, :active, :role)
      end

      # 現在のユーザーのメンバーシップ取得（権限チェック込み）
      def current_user_membership(group_id)
        Membership.find_by(user_id: current_user.id, group_id: group_id)
      end

      # nilの場合や非アクティブの場合に403エラー
      def validate_membership(membership)
        return handle_forbidden("You are not a member of this group") if membership.nil?
        return handle_forbidden("Your membership is not active") unless membership.active?
        membership
      end

      # Member権限チェック：指定されたグループのmember以上のみ操作可能
      def check_member_permission
        # indexアクションでgroup_id指定がない場合はチェック不要（既にフィルタリング済み）
        return if action_name == 'index' && params[:group_id].blank?
        
        group_id = get_group_id_for_action
        membership = current_user_membership(group_id)
        validate_membership(membership)
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        group_id = get_group_id_for_action
        return handle_unprocessable_entity(["Group ID is required"]) if group_id.nil?
        
        membership = current_user_membership(group_id)
        validate_membership(membership)
        
        return handle_forbidden("You are not allowed to perform this action. Admin permission required.") unless membership.admin?
      end

      # 共通メソッド：メンバーシップ情報のJSONレスポンスを生成
      def render_membership_success(membership, status = :ok)
        render json: membership, serializer: MembershipSerializer, status: status
      end

      # 共通メソッド：最後のAdminチェック
      def ensure_not_last_admin(membership, action_description = "perform this action")
        return true unless membership.admin?
        
        admin_count = Membership.where(group_id: membership.group_id, role: "admin").count
        if admin_count <= 1
          handle_forbidden("Cannot #{action_description}. Please assign admin role to another member first.")
          return false
        end
        true
      end

      # アクション別のgroup_id取得
      def get_group_id_for_action
        case action_name
        when 'index'
          params[:group_id]
        when 'create'
          params.dig(:membership, :group_id) || params.dig('membership', 'group_id')
        else
          @membership&.group_id
        end
      end
    end
  end
end