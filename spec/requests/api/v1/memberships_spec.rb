# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "Api::V1::Memberships", type: :request do
  let!(:group) { create(:group) }
  let!(:admin_user) { create(:user) }
  let!(:user) { create(:user) }
  let!(:admin_membership) { create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: 50) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 50) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
    allow_any_instance_of(Api::V1::MembershipsController).to receive(:authenticate_user!).and_return(true)
  end

  shared_examples 'not_found_membership' do
    it 'returns 404 with message' do
      subject
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Membership with ID")
    end
  end

  describe "GET /api/v1/memberships" do
    it "returns memberships for groups user belongs to" do
      get "/api/v1/memberships", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].map { |m| m["id"].to_i }).to include(admin_membership.id, member_membership.id)
    end

    it "filters by group_id if given" do
      get "/api/v1/memberships", params: { group_id: group.id }, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].map { |m| m["attributes"]["group_id"] }).to all(eq(group.id))
    end
  end

  describe "GET /api/v1/memberships/:id" do
    it "shows membership if user is group member" do
      get "/api/v1/memberships/#{member_membership.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(member_membership.id)
    end

    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_membership = create(:membership, group: other_group)
      get "/api/v1/memberships/#{other_membership.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    context "when membership does not exist" do
      subject { get "/api/v1/memberships/99999999", headers: headers }
      include_examples 'not_found_membership'
    end

    context "with invalid id format" do
      subject { get "/api/v1/memberships/invalid_id", headers: headers }
      include_examples 'not_found_membership'
    end
  end

  describe "POST /api/v1/memberships" do
    let!(:new_user) { create(:user) }
    let(:valid_params) do
      { membership: { user_id: new_user.id, group_id: group.id, active: true, role: "member", workload_ratio: 1.0 } }
    end

    it "creates membership as admin" do
      expect {
        post "/api/v1/memberships", params: valid_params, headers: headers
      }.to change(Membership, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["user_id"]).to eq(new_user.id)
    end

    it "returns error if params invalid" do
      post "/api/v1/memberships", params: { membership: { user_id: nil, group_id: group.id } }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      post "/api/v1/memberships", params: valid_params, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /api/v1/memberships/:id" do
    it "updates membership as admin" do
      put "/api/v1/memberships/#{member_membership.id}", params: { membership: { active: false } }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(member_membership.reload.active).to be false
    end

    context "when membership does not exist" do
      subject { put "/api/v1/memberships/99999999", params: { membership: { active: false } }, headers: headers }
      include_examples 'not_found_membership'
    end

    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      put "/api/v1/memberships/#{member_membership.id}", params: { membership: { active: false } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/memberships/:id" do
    it "deletes membership as admin (not last admin)" do
      membership = create(:membership, user: create(:user), group: group, role: 'member', active: true)
      expect {
        delete "/api/v1/memberships/#{membership.id}", headers: headers
      }.to change(Membership, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "prevents deleting last admin" do
      expect {
        delete "/api/v1/memberships/#{admin_membership.id}", headers: headers
      }.not_to change(Membership, :count)
      expect(response).to have_http_status(:forbidden)
    end

    context "when membership does not exist" do
      subject { delete "/api/v1/memberships/99999999", headers: headers }
      include_examples 'not_found_membership'
    end

    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      membership = create(:membership, user: create(:user), group: group, role: 'member', active: true)
      delete "/api/v1/memberships/#{membership.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/memberships/:id/change_role" do
    it "changes role as admin" do
      patch "/api/v1/memberships/#{member_membership.id}/change_role", params: { role: 'admin' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(member_membership.reload.role).to eq('admin')
    end

    it "prevents demoting last admin" do
      patch "/api/v1/memberships/#{admin_membership.id}/change_role", params: { role: 'member' }, headers: headers
      expect(response).to have_http_status(:forbidden)
      expect(admin_membership.reload.role).to eq('admin')
    end

    context "when membership does not exist" do
      subject { patch "/api/v1/memberships/99999999/change_role", params: { role: 'admin' }, headers: headers }
      include_examples 'not_found_membership'
    end

    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      patch "/api/v1/memberships/#{member_membership.id}/change_role", params: { role: 'admin' }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
