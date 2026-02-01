require 'rails_helper'

RSpec.describe "Api::V1::Memberships", type: :request do
  let!(:group) { create(:group) }
  let!(:admin_user) { create(:user) }
  let!(:user) { create(:user) }
  let!(:admin_membership) { create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: nil) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
    allow_any_instance_of(Api::V1::MembershipsController).to receive(:authenticate_user!).and_return(true)
  end

  # 共通系：404を返す
  shared_examples 'not_found_membership' do
    it 'returns 404 with message' do
      subject
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Membership with ID")
    end
  end

  describe "GET /api/v1/memberships" do
    # 正常系：ユーザーが所属するグループのメンバーシップ一覧取得
    it "returns memberships for groups user belongs to" do
      get "/api/v1/memberships", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].map { |m| m["id"].to_i }).to include(admin_membership.id, member_membership.id)
    end

    # 正常系：group_id指定でフィルタリング
    it "filters by group_id if given" do
      get "/api/v1/memberships", params: { group_id: group.id }, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"].map { |m| m["attributes"]["group_id"] }).to all(eq(group.id))
    end
  end

  describe "GET /api/v1/memberships/:id" do
    # 正常系：ユーザーが所属するグループのメンバーシップ取得
    it "shows membership if user is group member" do
      get "/api/v1/memberships/#{member_membership.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(member_membership.id)
    end

    # 異常系：ユーザーが所属しないグループのメンバーシップ取得で403を返す
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_membership = create(:membership, group: other_group)
      get "/api/v1/memberships/#{other_membership.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：存在しないmembershipの取得で404を返す
    context "when membership does not exist" do
      subject { get "/api/v1/memberships/99999999", headers: headers }
      include_examples 'not_found_membership'
    end

    # 異常系：ID形式が不正な場合で404を返す
    context "with invalid id format" do
      subject { get "/api/v1/memberships/invalid_id", headers: headers }
      include_examples 'not_found_membership'
    end
  end

  describe "POST /api/v1/memberships" do
    let!(:new_user) { create(:user) }
    let(:valid_params) do
      # 既存構成(admin=nil, member=100)に追加する際はnilで合計100を維持
      { membership: { user_id: new_user.id, group_id: group.id, active: true, role: "member", workload_ratio: nil } }
    end

    # 正常系：管理者がメンバーシップを作成
    it "creates membership as admin" do
      expect {
        post "/api/v1/memberships", params: valid_params, headers: headers
      }.to change(Membership, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["user_id"]).to eq(new_user.id)
    end

    # 異常系：パラメータ不正
    it "returns error if params invalid" do
      post "/api/v1/memberships", params: { membership: { user_id: nil, group_id: group.id } }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    # 異常系：重複したユーザーとグループのメンバーシップ作成
    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      post "/api/v1/memberships", params: valid_params, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /api/v1/memberships/:id" do
    # 正常系：管理者がメンバーシップを更新
    it "updates membership as admin" do
      put "/api/v1/memberships/#{member_membership.id}", params: { membership: { active: false } }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(member_membership.reload.active).to be false
    end

    # 異常系：存在しないmembershipの更新で404を返す
    context "when membership does not exist" do
      subject { put "/api/v1/memberships/99999999", params: { membership: { active: false } }, headers: headers }
      include_examples 'not_found_membership'
    end

    # 異常系：ID形式が不正な場合で404を返す
    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      put "/api/v1/memberships/#{member_membership.id}", params: { membership: { active: false } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/memberships/:id" do
    # 正常系：管理者がメンバーシップを削除（最後の管理者でない場合）
    it "deletes membership as admin (not last admin)" do
      # 合計100維持のため追加メンバーはnil比率
      membership = create(:membership, user: create(:user), group: group, role: 'member', active: true, workload_ratio: nil)
      expect {
        delete "/api/v1/memberships/#{membership.id}", headers: headers
      }.to change(Membership, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    # 異常系：最後の管理者のメンバーシップ削除で403を返す
    it "prevents deleting last admin" do
      expect {
        delete "/api/v1/memberships/#{admin_membership.id}", headers: headers
      }.not_to change(Membership, :count)
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：存在しないmembershipの削除で404を返す
    context "when membership does not exist" do
      subject { delete "/api/v1/memberships/99999999", headers: headers }
      include_examples 'not_found_membership'
    end

    # 異常系：ID形式が不正な場合で404を返す
    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      membership = create(:membership, user: create(:user), group: group, role: 'member', active: true, workload_ratio: nil)
      delete "/api/v1/memberships/#{membership.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/memberships/:id/change_role" do
    # 正常系：管理者がメンバーシップの役割を変更
    it "changes role as admin" do
      patch "/api/v1/memberships/#{member_membership.id}/change_role", params: { role: 'admin' }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(member_membership.reload.role).to eq('admin')
    end

    # 異常系：最後の管理者を降格させようとした場合で403を返す
    it "prevents demoting last admin" do
      patch "/api/v1/memberships/#{admin_membership.id}/change_role", params: { role: 'member' }, headers: headers
      expect(response).to have_http_status(:forbidden)
      expect(admin_membership.reload.role).to eq('admin')
    end

    # 異常系：存在しないmembershipの役割変更で404を返す
    context "when membership does not exist" do
      subject { patch "/api/v1/memberships/99999999/change_role", params: { role: 'admin' }, headers: headers }
      include_examples 'not_found_membership'
    end

    # 異常系：ID形式が不正な場合で404を返す
    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      patch "/api/v1/memberships/#{member_membership.id}/change_role", params: { role: 'admin' }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
