# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::V1::Groups", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:group) { create(:group) }
  
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    # テスト環境で認証をモック - authenticate_user!をスキップ
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::GroupsController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/groups" do
    context "when user is member of groups" do
      let!(:membership1) { create(:membership, user: user, group: group, role: 'member', active: true) }
      let!(:membership2) { create(:membership, user: user, role: 'admin', active: true) }
      let!(:inactive_membership) { create(:membership, user: user, role: 'member', active: false) }

      it "returns only groups where user has active membership" do
        get "/api/v1/groups", headers: headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key("data")
        expect(json_response["data"]).to be_an(Array)
        expect(json_response["data"].length).to eq(2)
        
        group_ids = json_response["data"].map { |g| g["id"].to_i }
        expect(group_ids).to include(group.id, membership2.group.id)
        expect(group_ids).not_to include(inactive_membership.group.id)
      end
    end

    context "when user has no active memberships" do
      it "returns empty array" do
        get "/api/v1/groups", headers: headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response["data"]).to eq([])
      end
    end

    context "when user is not authenticated" do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
        allow_any_instance_of(Api::V1::GroupsController).to receive(:authenticate_user!).and_call_original
      end

      it "returns unauthorized status" do
        get "/api/v1/groups", headers: headers

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/groups/:id" do
    let!(:membership) { create(:membership, user: user, group: group, role: 'member', active: true) }

    context "when user is member of the group" do
      it "returns group details" do
        get "/api/v1/groups/#{group.id}", headers: headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response["data"]["id"].to_i).to eq(group.id)
        expect(json_response["data"]["attributes"]["name"]).to eq(group.name)
        expect(json_response["data"]["attributes"]["share_key"]).to eq(group.share_key)
      end
    end

    context "when user is not member of the group" do
      let(:other_group) { create(:group) }

      it "returns forbidden status" do
        get "/api/v1/groups/#{other_group.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to include("not a member")
      end
    end

    context "when group does not exist" do
      it "returns not found status" do
        get "/api/v1/groups/99999", headers: headers

        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to include("not found")
      end
    end

    context "when user has inactive membership" do
      before do
        membership.update!(active: false)
      end

      it "returns forbidden status" do
        get "/api/v1/groups/#{group.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to include("membership is not active")
      end
    end

    it "returns 404 if group id is invalid" do
      get "/api/v1/groups/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response["message"]).to include("not found")
    end
  end

  describe "POST /api/v1/groups" do
    let(:valid_attributes) do
      {
        group: {
          name: "New Test Group",
          share_key: "new-test-key",
          assign_mode: "manual",
          balance_type: "point"
        }
      }
    end

    context "with valid parameters" do
      it "creates a new group and makes user admin" do
        expect {
          post "/api/v1/groups", params: valid_attributes, headers: headers
        }.to change(Group, :count).by(1).and change(Membership, :count).by(1)

        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response["data"]["attributes"]["name"]).to eq("New Test Group")
        expect(json_response["data"]["attributes"]["share_key"]).to eq("new-test-key")
        
        # ユーザーが管理者として追加されることを確認
        new_group = Group.find(json_response["data"]["id"])
        membership = new_group.memberships.find_by(user: user)
        expect(membership).to be_present
        expect(membership.role).to eq("admin")
        expect(membership.active).to be true
      end
    end

    context "with invalid parameters" do
      let(:invalid_attributes) do
        {
          group: {
            name: "", # 必須フィールドが空
            share_key: "test-key"
          }
        }
      end

      it "returns unprocessable entity status" do
        post "/api/v1/groups", params: invalid_attributes, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to be_present
      end
    end

    context "with duplicate share_key" do
      let!(:existing_group) { create(:group, share_key: "duplicate-key") }
      let(:duplicate_attributes) do
        {
          group: {
            name: "Another Group",
            share_key: "duplicate-key"
          }
        }
      end

      it "returns unprocessable entity status" do
        post "/api/v1/groups", params: duplicate_attributes, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        
        json_response = JSON.parse(response.body)
        expect(json_response["errors"]).to include("Share key has already been taken")
      end
    end
  end

  describe "PATCH /api/v1/groups/:id" do
    let!(:membership) { create(:membership, user: user, group: group, role: 'admin', active: true) }
    let(:update_attributes) do
      {
        group: {
          name: "Updated Group Name",
          assign_mode: "manual"
        }
      }
    end

    context "when user is admin of the group" do
      it "updates the group successfully" do
        patch "/api/v1/groups/#{group.id}", params: update_attributes, headers: headers

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response["data"]["attributes"]["name"]).to eq("Updated Group Name")
        expect(json_response["data"]["attributes"]["assign_mode"]).to eq("manual")
        
        group.reload
        expect(group.name).to eq("Updated Group Name")
        expect(group.assign_mode).to eq("manual")
      end
    end

    context "when user is not admin of the group" do
      before do
        membership.update!(role: 'member')
      end

      it "returns forbidden status" do
        patch "/api/v1/groups/#{group.id}", params: update_attributes, headers: headers

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to include("Admin permission required")
      end
    end

    context "with invalid parameters" do
      let(:invalid_update) do
        {
          group: {
            name: "" # 必須フィールドを空に
          }
        }
      end

      it "returns unprocessable entity status" do
        patch "/api/v1/groups/#{group.id}", params: invalid_update, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to be_present
      end
    end

    it "returns 404 if group does not exist" do
      patch "/api/v1/groups/99999999", params: update_attributes, headers: headers
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response["message"]).to include("not found")
    end

    it "returns 404 if group id is invalid" do
      patch "/api/v1/groups/invalid_id", params: update_attributes, headers: headers
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response["message"]).to include("not found")
    end
  end

  describe "DELETE /api/v1/groups/:id" do
    let!(:membership) { create(:membership, user: user, group: group, role: 'admin', active: true) }
    let!(:task) { create(:task, group: group) }

    context "when user is admin of the group" do
      it "deletes the group and related data" do
        expect {
          delete "/api/v1/groups/#{group.id}", headers: headers
        }.to change(Group, :count).by(-1)
         .and change(Membership, :count).by(-1)
         .and change(Task, :count).by(-1)

        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to include("successfully deleted")
        expect(json_response["deleted_at"]).to be_present
      end
    end

    context "when user is not admin of the group" do
      before do
        membership.update!(role: 'member')
      end

      it "returns forbidden status" do
        delete "/api/v1/groups/#{group.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to include("Admin permission required")
        
        # グループが削除されていないことを確認
        expect(Group.exists?(group.id)).to be true
      end
    end

    context "when user is not member of the group" do
      let(:other_group) { create(:group) }

      it "returns forbidden status" do
        delete "/api/v1/groups/#{other_group.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
        
        json_response = JSON.parse(response.body)
        expect(json_response["message"]).to include("not a member")
      end
    end

    it "returns 404 if group does not exist" do
      delete "/api/v1/groups/99999999", headers: headers
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response["message"]).to include("not found")
    end

    it "returns 404 if group id is invalid" do
      delete "/api/v1/groups/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
      json_response = JSON.parse(response.body)
      expect(json_response["message"]).to include("not found")
    end
  end
end
