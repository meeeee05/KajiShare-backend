module Api
  module V1
    class MembershipsController < ApplicationController
      before_action :set_membership, only: [:show, :update, :destroy]
      before_action :authenticate_user!, only: [:create, :update, :destroy]
      before_action :check_admin_permission, only: [:create, :update, :destroy]

      def index
        memberships = Membership.all
        render json: memberships
      end

      def show
        render json: @membership
      end

      def create
        membership = Membership.new(membership_params)
        if membership.save
          render json: membership, status: :created
        else
          render json: { errors: membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def update
        if @membership.update(membership_params)
          render json: @membership
        else
          render json: { errors: @membership.errors.full_messages }, status: :unprocessable_entity
        end
      end

      def destroy
        @membership.destroy
        head :no_content
      end

      private

      def set_membership
        @membership = Membership.find(params[:id])
      end

      def membership_params
        params.require(:membership).permit(:user_id, :group_id, :role, :workload_ratio, :active)
      end

      # Admin権限チェック：指定されたグループのAdmin権限を持つユーザーのみ操作可能
      def check_admin_permission
        # group_idの取得（新規作成時はパラメータから、更新・削除時は既存レコードから）
        group_id = action_name == 'create' ? membership_params[:group_id] : @membership.group_id
        
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