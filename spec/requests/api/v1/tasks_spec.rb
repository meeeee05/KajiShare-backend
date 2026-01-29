# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "Api::V1::Tasks", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:group) { create(:group) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }
  let(:json) { JSON.parse(response.body) }
  let!(:task) { create(:task, group: group) }

  # 共通：Userを常に認証
  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user)
      .and_return(user)

    # 認証の詳細はテストしない  
    allow_any_instance_of(Api::V1::TasksController)
      .to receive(:authenticate_user!)
      .and_return(true)
  end

  # 共通：403エラー出力
  shared_examples 'forbidden' do
    it { expect(response).to have_http_status(:forbidden) }
  end

  # 共通：404エラー出力（messageは見ない）
  shared_examples 'not_found' do
    it { expect(response).to have_http_status(:not_found) }
  end

  describe "GET /api/v1/groups/:group_id/tasks" do
    # 正常系：グループメンバーとしてのアクセス
    context "as group member" do
      it "returns tasks for group" do
        create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100)
        get "/api/v1/groups/#{group.id}/tasks", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json["data"]).to be_an(Array)
        expect(json["data"].first["id"].to_i).to eq(task.id)
      end
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "as non-member" do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(create(:user))
        get "/api/v1/groups/#{group.id}/tasks", headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end

  describe "GET /api/v1/tasks/:id" do
    # 正常系：グループメンバーとしてのアクセス
    context "as group member" do
      it "shows task" do
        create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100)
        get "/api/v1/tasks/#{task.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json["data"]["id"].to_i).to eq(task.id)
        expect(json["data"]["attributes"]["name"]).to eq(task.name)
      end
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "as non-member" do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(create(:user))
        get "/api/v1/tasks/#{task.id}", headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end

  describe "POST /api/v1/groups/:group_id/tasks" do
    # 正常系：グループメンバーとしてのアクセス
    let(:valid_params) do
      { task: { name: "New Task", description: "desc", point: 10 } }
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "as group member" do
      it "creates task" do
        create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100)
        expect {
          post "/api/v1/groups/#{group.id}/tasks",
               params: valid_params,
               headers: headers
        }.to change(Task, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json["data"]["attributes"]["name"]).to eq("New Task")
      end

      # 異常系：パラメータ不正
      it "returns error if params invalid" do
        create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100)
        post "/api/v1/groups/#{group.id}/tasks",
             params: { task: { name: "" } },
             headers: headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "as non-member" do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(create(:user))

        post "/api/v1/groups/#{group.id}/tasks",
             params: valid_params,
             headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    let(:update_params) { { task: { name: "Updated Task" } } }
    # 正常系：グループメンバーとしてのアクセス
    context "as group member" do
      it "updates task" do
        create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100)
        patch "/api/v1/tasks/#{task.id}",
              params: update_params,
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(task.reload.name).to eq("Updated Task")
      end
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "as non-member" do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(create(:user))

        patch "/api/v1/tasks/#{task.id}",
              params: update_params,
              headers: headers
      end

      it_behaves_like 'forbidden'
    end

    # 異常系：タスクが存在しない場合
    context "task does not exist" do
      before do
        patch "/api/v1/tasks/99999999",
              params: update_params,
              headers: headers
      end

      it_behaves_like 'not_found'
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    # 正常系：グループ管理者としてのアクセス
    context "as admin" do
      before do
        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: 100)
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(admin_user)
      end

      # 正常系：タスク削除
      it "deletes task" do
        task_to_delete = create(:task, group: group)
        expect {
          delete "/api/v1/tasks/#{task_to_delete.id}", headers: headers
        }.to change(Task, :count).by(-1)
        expect(response).to have_http_status(:ok)
      end

      # 異常系：タスクが存在しない場合
      context "task does not exist" do
        before { delete "/api/v1/tasks/99999999", headers: headers }
        it_behaves_like 'not_found'
      end
    end

    # 異常系：グループ非管理者としてのアクセス
    context "as non-admin" do
      before do
        non_admin_user = create(:user)
        create(:membership, user: non_admin_user, group: group, role: 'member', active: true, workload_ratio: 100)
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(non_admin_user)
        delete "/api/v1/tasks/#{task.id}", headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end
end