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

    # 正常系：アクティブなグループのみ取得
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

    # 異常系：アクティブなメンバーシップがない場合、空配列を返す
    it "returns empty array if no active memberships" do
      get "/api/v1/groups", headers: headers
      expect(json_response["data"]).to eq([])
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す
    it "returns unauthorized if not authenticated" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(nil)
      allow_any_instance_of(Api::V1::GroupsController).to receive(:authenticate_user!).and_call_original
      get "/api/v1/groups", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/groups/:id" do

    # 正常系：グループメンバーとしてのアクセス
    it "returns group details if user is member" do
      group = create(:group)
      create(:membership, user: user, group: group, active: true)
      get "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["id"].to_i).to eq(group.id)
    end

    # 異常系：グループ非メンバーとしてのアクセス
    it "returns forbidden if user is not member" do
      group = create(:group)
      get "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：存在しないグループIDの場合、404を返す
    it "returns not found if group does not exist" do
      get "/api/v1/groups/99999", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    # 異常系：非アクティブなメンバーシップの場合、403を返す
    it "returns forbidden if membership is inactive" do
      group = create(:group)
      m = create(:membership, user: user, group: group, active: false)
      get "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：無効なID形式の場合、404を返す
    it "returns 404 if group id is invalid" do
      get "/api/v1/groups/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/groups" do

    # 正常系：新規グループ作成とユーザーを管理者に設定
    it "creates a new group and makes user admin" do
      attrs = { group: { name: "New Test Group", share_key: "new-test-key", assign_mode: "manual", balance_type: "point" } }
      expect {
        post "/api/v1/groups", params: attrs, headers: headers
      }.to change(Group, :count).by(1).and change(Membership, :count).by(1)
      expect(response).to have_http_status(:created)
      expect(json_response["data"]["attributes"]["name"]).to eq("New Test Group")
    end

    # 異常系：バリデーションエラー時のレスポンス確認
    it "returns unprocessable if params invalid" do
      attrs = { group: { name: "", share_key: "test-key" } }
      post "/api/v1/groups", params: attrs, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("Unprocessable Entity")
      expect(body["errors"]).to include("Name can't be blank")
    end

    # 異常系：share_keyが重複する場合のエラーレスポンス確認
    it "returns unprocessable if share_key duplicate" do
      create(:group, share_key: "dup-key")
      attrs = { group: { name: "Another Group", share_key: "dup-key" } }
      post "/api/v1/groups", params: attrs, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include("Share key has already been taken")
    end
  end

  describe "PATCH /api/v1/groups/:id" do

    # 正常系：グループ管理者としての更新
    it "updates group if user is admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      attrs = { group: { name: "Updated Group Name", assign_mode: "manual" } }
      patch "/api/v1/groups/#{group.id}", params: attrs, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["attributes"]["name"]).to eq("Updated Group Name")
    end

    # 異常系：グループ管理者でない場合の更新拒否
    it "returns forbidden if not admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'member', active: true)
      attrs = { group: { name: "Updated Group Name" } }
      patch "/api/v1/groups/#{group.id}", params: attrs, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：グループ非メンバーの場合の更新拒否
    it "returns unprocessable if params invalid" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      attrs = { group: { name: "" } }
      patch "/api/v1/groups/#{group.id}", params: attrs, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body["errors"]).to include("Name can't be blank")
    end

    # 異常系：存在しないグループIDの場合、404を返す
    it "returns 404 if group does not exist" do
      attrs = { group: { name: "Updated Group Name" } }
      patch "/api/v1/groups/99999999", params: attrs, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    # 異常系：無効なID形式の場合、404を返す
    it "returns 404 if group id is invalid" do
      attrs = { group: { name: "Updated Group Name" } }
      patch "/api/v1/groups/invalid_id", params: attrs, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "Authentication" do
    before do
      allow_any_instance_of(Api::V1::GroupsController)
        .to receive(:authenticate_user!)
        .and_call_original
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user)
        .and_call_original
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す(post)
    it "returns unauthorized for create without Authorization header" do
      attrs = { group: { name: "No Auth Group", share_key: "no-auth-key", assign_mode: "manual", balance_type: "point" } }
      post "/api/v1/groups", params: attrs
      expect(response).to have_http_status(:unauthorized)
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す(patch)
    it "returns unauthorized for update without Authorization header" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      attrs = { group: { name: "Updated Group Name" } }
      patch "/api/v1/groups/#{group.id}", params: attrs
      expect(response).to have_http_status(:unauthorized)
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す(delete)
    it "returns unauthorized for delete without Authorization header" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      delete "/api/v1/groups/#{group.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/groups/:id" do

    # 正常系：グループ管理者としての削除
    it "deletes group if user is admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'admin', active: true)
      task = create(:task, group: group)
      expect {
        delete "/api/v1/groups/#{group.id}", headers: headers
      }.to change(Group, :count).by(-1)
      expect(response).to have_http_status(:ok)
    end

    # 異常系：グループ管理者でない場合の削除拒否
    it "returns forbidden if not admin" do
      group = create(:group)
      create(:membership, user: user, group: group, role: 'member', active: true)
      delete "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：グループ非メンバーの場合の削除拒否
    it "returns forbidden if not member" do
      group = create(:group)
      delete "/api/v1/groups/#{group.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：存在しないグループIDの場合、404を返す
    it "returns 404 if group does not exist" do
      delete "/api/v1/groups/99999999", headers: headers
      expect(response).to have_http_status(:not_found)
    end

    # 異常系：無効なID形式の場合、404を返す
    it "returns 404 if group id is invalid" do
      delete "/api/v1/groups/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
