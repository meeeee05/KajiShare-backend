require 'rails_helper'

RSpec.describe "Api::V1::Groups", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }
  let(:json_response) { JSON.parse(response.body) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::GroupsController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/groups" do
    it "returns only active groups" do
      group1 = create(:group)
      group2 = create(:group)
      create(:membership, user: user, group: group1, active: true)
      create(:membership, user: user, group: group2, active: false)

      get "/api/v1/groups", headers: headers
      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |g| g["id"].to_i }
      expect(ids).to contain_exactly(group1.id)
    end

    it "returns empty array if no active memberships" do
      get "/api/v1/groups", headers: headers
      expect(json_response["data"]).to eq([])
    end

    it "returns unauthorized if not authenticated" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(Api::V1::GroupsController).to receive(:authenticate_user!).and_call_original
      get "/api/v1/groups", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/groups/:id" do
    it "returns group details if user is member" do
      group = create(:group)
      create(:membership, user: user, group: group, active: true)
      get "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["id"].to_i).to eq(group.id)
    end

    it "returns forbidden if user is not member" do
      group = create(:group)
      get "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns not found if group does not exist" do
      get "/api/v1/groups/99999", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns forbidden if membership is inactive" do
      group = create(:group)
      m = create(:membership, user: user, group: group, active: false)
      get "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 if group id is invalid" do
      get "/api/v1/groups/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/groups" do
    it "creates a new group and makes user admin" do
      attrs = { group: { name: "New Test Group", share_key: "new-test-key", assign_mode: "manual", balance_type: "point" } }
      expect {
        post "/api/v1/groups", params: attrs, headers: headers
      }.to change(Group, :count).by(1).and change(Membership, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(json_response["data"]["attributes"]["name"]).to eq("New Test Group")
    end

    it "returns unprocessable if params invalid" do
      attrs = { group: { name: "", share_key: "test-key" } }
      post "/api/v1/groups", params: attrs, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns unprocessable if share_key duplicate" do
      create(:group, share_key: "dup-key")
      attrs = { group: { name: "Another Group", share_key: "dup-key" } }
      post "/api/v1/groups", params: attrs, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /api/v1/groups/:id" do
    it "updates group if user is admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      attrs = { group: { name: "Updated Group Name", assign_mode: "manual" } }
      patch "/api/v1/groups/#{group.id}", params: attrs, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["attributes"]["name"]).to eq("Updated Group Name")
    end

    it "returns forbidden if not admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'member', active: true)
      attrs = { group: { name: "Updated Group Name" } }
      patch "/api/v1/groups/#{group.id}", params: attrs, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns unprocessable if params invalid" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      attrs = { group: { name: "" } }
      patch "/api/v1/groups/#{group.id}", params: attrs, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 if group does not exist" do
      attrs = { group: { name: "Updated Group Name" } }
      patch "/api/v1/groups/99999999", params: attrs, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 if group id is invalid" do
      attrs = { group: { name: "Updated Group Name" } }
      patch "/api/v1/groups/invalid_id", params: attrs, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/groups/:id" do
    it "deletes group if user is admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      task = create(:task, group: group)
      expect {
        delete "/api/v1/groups/#{group.id}", headers: headers
      }.to change(Group, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    it "returns forbidden if not admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'member', active: true)
      delete "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns forbidden if not member" do
      group = create(:group)
      delete "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 if group does not exist" do
      delete "/api/v1/groups/99999999", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it "returns 404 if group id is invalid" do
      delete "/api/v1/groups/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
