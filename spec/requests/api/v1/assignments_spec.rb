require 'rails_helper'

RSpec.describe "Api::V1::Assignments", type: :request do
  let(:json_response) { JSON.parse(response.body) }
  let!(:group) { create(:group) }
  let!(:user) { create(:user) }
  let!(:admin_user) { create(:user) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100) }
  let!(:task) { create(:task, group: group) }
  let!(:assignment) { create(:assignment, task: task, membership: member_membership) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::AssignmentsController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/tasks/:task_id/assignments" do
    subject { get "/api/v1/tasks/#{task_id}/assignments", headers: headers }
    # 正常系：グループメンバーとしてのアクセス
    context "when user is member" do
      let(:task_id) { task.id }
      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response["data"]).to be_an(Array)
        expect(json_response["data"].first["id"].to_i).to eq(assignment.id)
      end
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "when user is not group member" do
      let(:other_group) { create(:group) }
      let(:task_id) { create(:task, group: other_group).id }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    # 異常系：taskが存在しない場合
    context "when task does not exist" do
      let(:task_id) { 99999999 }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    # 異常系：id形式が不正な場合
    context "when id format is invalid" do
      let(:task_id) { 'invalid_id' }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /api/v1/assignments/:id" do
    subject { get "/api/v1/assignments/#{assignment_id}", headers: headers }
    # 正常系：グループメンバーとしてのアクセス
    context "when user is group member" do
      let(:assignment_id) { assignment.id }
      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response["data"]["id"].to_i).to eq(assignment.id)
      end
    end

    # 異常系：assignmentが存在しない場合
    context "when assignment does not exist" do
      let(:assignment_id) { 99999999 }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    # 異常系：id形式が不正な場合
    context "when id format is invalid" do
      let(:assignment_id) { 'invalid_id' }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "when user is not group member" do
      let(:other_group) { create(:group) }
      let(:other_task) { create(:task, group: other_group) }
      let(:other_membership) { create(:membership, user: create(:user), group: other_group, role: 'member', active: true, workload_ratio: 100) }
      let(:assignment_id) { create(:assignment, task: other_task, membership: other_membership).id }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "POST /api/v1/tasks/:task_id/assignments" do
    # 正常系：グループメンバーとしてのアクセス
    let(:valid_params) { { assignment: { due_date: Date.tomorrow, comment: "test" } } }
    subject { post "/api/v1/tasks/#{task_id}/assignments", params: params, headers: headers }

    # 正常系：グループメンバーとしてのアクセス
    context "when user is member" do
      let(:task_id) { task.id }
      let(:params) { valid_params }
      it "creates assignment" do
        another_user = create(:user)
        # 既存メンバーは100のまま、追加メンバーはnilで合計100を維持
        create(:membership, user: another_user, group: group, role: 'member', active: true, workload_ratio: nil)
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(another_user)
        expect { post "/api/v1/tasks/#{task.id}/assignments", params: valid_params, headers: headers }.to change(Assignment, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(json_response["data"]["attributes"]["comment"]).to eq("test")
      end
    end

    # 異常系：パラメータ不正
    context "when params invalid" do
      let(:task_id) { task.id }
      let(:params) { { assignment: { due_date: nil } } }
      it do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response["errors"]).to be_present
      end
    end

    # 異常系：グループ非メンバーとしてのアクセス
    context "when user is not group member" do
      let(:other_group) { create(:group) }
      let(:task_id) { create(:task, group: other_group).id }
      let(:params) { { assignment: { due_date: Date.tomorrow } } }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    # 異常系：taskが存在しない場合
    context "when task does not exist" do
      let(:task_id) { 99999999 }
      let(:params) { { assignment: { due_date: Date.tomorrow } } }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    # 異常系：id形式が不正な場合
    context "when id format is invalid" do
      let(:task_id) { 'invalid_id' }
      let(:params) { { assignment: { due_date: Date.tomorrow } } }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "PATCH /api/v1/assignments/:id" do
    # 正常系：グループメンバーとしてのアクセス
    let(:update_params) { { assignment: { comment: "updated" } } }
    subject { patch "/api/v1/assignments/#{assignment_id}", params: params, headers: headers }

    # 正常系：グループメンバーとしてのアクセス
    context "when user is member" do
      let(:assignment_id) { assignment.id }
      let(:params) { update_params }
      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response["data"]["attributes"]["comment"]).to eq("updated")
      end
    end

    # 異常系：assignmentが存在しない場合
    context "when assignment does not exist" do
      let(:assignment_id) { 99999999 }
      let(:params) { { assignment: { comment: "x" } } }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

    # 異常系：id形式が不正な場合
    context "when user is not group member" do
      let(:other_group) { create(:group) }
      let(:other_task) { create(:task, group: other_group) }
      let(:other_membership) { create(:membership, user: create(:user), group: other_group, role: 'member', active: true, workload_ratio: 100) }
      let(:assignment_id) { create(:assignment, task: other_task, membership: other_membership).id }
      let(:params) { { assignment: { comment: "x" } } }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /api/v1/assignments/:id" do
    subject { delete "/api/v1/assignments/#{assignment_id}", headers: headers }
    # 正常系：グループ管理者としてのアクセス
    context "when user is admin" do
      let!(:admin_membership) do
        # 既存メンバーは100のまま、管理者はnilで合計100を維持
        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: nil)
      end
      let!(:admin_assignment) { create(:assignment, task: task, membership: admin_membership) }
      let(:assignment_id) { admin_assignment.id }
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user) }
      it do
        expect { subject }.to change(Assignment, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(json_response["message"]).to include("successfully deleted")
      end
    end

    # 異常系：グループ管理者でない場合のアクセス拒否
    context "when not admin" do
      let!(:admin_membership) do
        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: nil)
      end
      let(:assignment_id) { create(:assignment, task: task, membership: admin_membership).id }
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user) }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    # 異常系：assignmentが存在しない場合
    context "when assignment does not exist" do
      let(:assignment_id) { 99999999 }
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user) }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "Authentication" do
    before do
      allow_any_instance_of(Api::V1::AssignmentsController).to receive(:authenticate_user!).and_call_original
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_call_original
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す(get)
    it "returns 401 for index without Authorization header" do
      get "/api/v1/tasks/#{task.id}/assignments"
      expect(response).to have_http_status(:unauthorized)
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す(post)
    it "returns 401 for create without Authorization header" do
      post "/api/v1/tasks/#{task.id}/assignments", params: { assignment: { due_date: Date.tomorrow, comment: "x" } }
      expect(response).to have_http_status(:unauthorized)
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す(patch)
    it "returns 401 for update without Authorization header" do
      patch "/api/v1/assignments/#{assignment.id}", params: { assignment: { comment: "x" } }
      expect(response).to have_http_status(:unauthorized)
    end

    # 異常系：Authorizationヘッダーがない場合、401を返す(delete)
    it "returns 401 for delete without Authorization header" do
      delete "/api/v1/assignments/#{assignment.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "Validation and status sync" do
    # 異常系：期限日前に完了日があるアサインメントは作成不可
    it "returns 422 when completed_date is before due_date on create" do
      post "/api/v1/tasks/#{task.id}/assignments",
           params: { assignment: { due_date: Date.tomorrow, completed_date: Date.current, comment: "bad" } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]).to eq("Unprocessable Entity")
      expect(json_response["message"]).to eq("Validation failed")
      expect(json_response["errors"]).to be_an(Array)
      expect(json_response["errors"].any? { |e| e.include?("期限日以降") }).to be(true)
    end

    # 正常系：完了日がある場合、ステータスがcompletedに同期される
    it "syncs status to completed when completed_date is present on update" do
      patch "/api/v1/assignments/#{assignment.id}",
            params: { assignment: { due_date: Date.current, completed_date: Date.current, comment: "done" } },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]["attributes"]["status"]).to eq("completed")
    end

    # 異常系：同じtaskとmembershipの重複したassignmentを作成しようとした場合
    it "returns 422 when creating duplicate assignment for same task and membership" do
      post "/api/v1/tasks/#{task.id}/assignments",
           params: { assignment: { due_date: Date.tomorrow, comment: "dup" } },
           headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["error"]).to eq("Unprocessable Entity")
      expect(json_response["message"]).to eq("Validation failed")
      expect(json_response["errors"]).to include("Task has already been taken")
    end
  end
end
