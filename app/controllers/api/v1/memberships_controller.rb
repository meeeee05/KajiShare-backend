module Api
  module V1
    class MembershipsController < ApplicationController
      before_action :set_membership, only: [:show, :update, :destroy]

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
    end
  end
end