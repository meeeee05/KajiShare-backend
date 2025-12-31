module Api
  module V1
    class MembershipsController < ApplicationController
      before_action :set_membership, only: [:show, :update, :destroy, :change_role]
      before_action :authenticate_user!  # 全アクションで認証必須
      before_action :check_member_permission, only: [:index, :show]  # 参照はメンバー権限以上
      before_action :check_admin_permission, only: [:create, :update, :destroy, :change_role]

      # GET /api/v1/memberships - 現在のユーザーが参加しているグループのメンバーシップのみ返す
      def index
        # クエリパラメータでgroup_idが指定された場合はそのグループのみ、未指定なら全ての参加グループを取得
        if params[:group_id].present?
          group_id = params[:group_id]
          # 指定されたグループのメンバーかチェック
          user_membership = current_user_membership(group_id)
          if user_membership.nil?
            return handle_forbidden("You are not a member of this group")
          end
          memberships = Membership.where(group_id: group_id)
        else
          # 現在のユーザーが参加している全グループのメンバーシップを取得
          user_group_ids = current_user.memberships.where(active: true).pluck(:group_id)
          memberships = Membership.where(group_id: user_group_ids)
        end
        render json: memberships, each_serializer: MembershipSerializer
      end

      # GET /api/v1/memberships/:id - 同じグループのメンバーのみアクセス可能
      def show
        render json: @membership, serializer: MembershipSerializer
      end

      def create
        membership = Membership.new(membership_params)
        if membership.save
          render json: membership, serializer: MembershipSerializer, status: :created
        else
          handle_unprocessable_entity(membership.errors.full_messages)
        end
      end

      def update
        if @membership.update(membership_params)
          render json: @membership, serializer: MembershipSerializer
        else
          handle_unprocessable_entity(@membership.errors.full_messages)
        end
      end

      def destroy
        # Group最後のAdminは削除できないようにする　422
        if @membership.role == "admin"
          admin_count = Membership.where(group_id: @membership.group_id, role: "admin").count
          if admin_count <= 1
            return handle_forbidden("Cannot delete the last admin of the group. Please assign admin role to another member first.")
          end
        end

        # 削除ログ記録
        Rails.logger.info "Deleting membership: User #{@membership.user.name} from Group #{@membership.group.name} by admin #{current_user.name}"
        
        @membership.destroy
        head :no_content
      end

      # PATCH /api/v1/memberships/:id/change_role - Admin権限でロール変更専用エンドポイント
      # AdminからMemberへの変更時に、最後のAdminではないかを確認
      def change_role
        new_role = params[:role]
        
        unless ['admin', 'member'].include?(new_role)
          return handle_unprocessable_entity(["Invalid role. Must be 'admin' or 'member'"])
        end

        # 現在のロール（権限）と同じ場合は何もしない
        if @membership.role == new_role
          return render json: { message: "Role is already #{new_role}" }, status: :ok
        end

        # AdminからMemberに変更する場合の制限チェック
        if @membership.role == "admin" && new_role == "member"
          admin_count = Membership.where(group_id: @membership.group_id, role: "admin").count
          if admin_count <= 1
            return handle_forbidden("Cannot demote the last admin. Please promote another member to admin first.")
          end
        end

        # ロール変更実行
        if @membership.update(role: new_role)
          Rails.logger.info "Role changed: User #{@membership.user.name} in Group #{@membership.group.name} from #{@membership.role_was} to #{new_role} by admin #{current_user.name}"
          render json: { 
            message: "Role successfully changed to #{new_role}",
            membership: MembershipSerializer.new(@membership).as_json
          }, status: :ok
        else
          handle_unprocessable_entity(@membership.errors.full_messages)
        end
      end

      private

      def set_membership
        @membership = Membership.find(params[:id])
      rescue ActiveRecord::RecordNotFound => e
        handle_not_found("Membership with ID #{params[:id]} not found")
      end

      # 通常の更新用パラメータ（roleは専用エンドポイントで変更）
      def membership_params
        # roleの変更は専用のchange_roleエンドポイントでのみ可能
        params.require(:membership).permit(:user_id, :group_id, :workload_ratio, :active)
      end

      # 現在のユーザーのメンバーシップ取得
      def current_user_membership(group_id)
        Membership.find_by(user_id: current_user.id, group_id: group_id)
      end

      # Member権限チェック：指定されたグループのmember以上のみ操作可能
      def check_member_permission
        # indexアクションでgroup_id指定がない場合はチェック不要（既にフィルタリング済み）
        return if action_name == 'index' && params[:group_id].blank?
        
        # group_idの取得
        group_id = case action_name
                   when 'index' then params[:group_id]
                   when 'show' then @membership.group_id
                   end
        
        membership = current_user_membership(group_id)

        return handle_forbidden("You are not a member of this group") if membership.nil?
        return handle_forbidden("Your membership is not active") unless membership.active?
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        # group_idの取得（新規作成時はパラメータから、更新・削除時は既存レコードから）
        group_id = action_name == 'create' ? membership_params[:group_id] : @membership.group_id
        
        membership = current_user_membership(group_id)

        return handle_forbidden("You are not a member of this group") if membership.nil?
        return handle_forbidden("You are not allowed to perform this action. Admin permission required.") unless membership.role == "admin"
      end
    end
  end
end