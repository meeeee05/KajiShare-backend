require 'rails_helper'

RSpec.describe "Api::V1::Evaluations", type: :request do
  let!(:group) { create(:group) }
  let!(:user) { create(:user) }
  let!(:admin_user) { create(:user) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100) }
  let!(:admin_membership) { create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: nil) }
  let!(:task) { create(:task, group: group) }
  let!(:assignment) { create(:assignment, :completed, task: task, membership: member_membership, due_date: 2.days.ago, completed_date: 1.day.ago) }
  let!(:evaluation) { create(:evaluation, assignment: assignment, evaluator_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::EvaluationsController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/evaluations" do
    # 正常系：グループメンバーとしてのアクセス
    it "returns evaluations for groups user belongs to" do
      get "/api/v1/evaluations", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].map { |e| e["id"].to_i }).to include(evaluation.id)
    end
  end

  describe "Authentication" do
    before do
      allow_any_instance_of(Api::V1::EvaluationsController)
        .to receive(:authenticate_user!)
        .and_call_original
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user)
        .and_call_original
    end

    # 共通系：Authorizationヘッダーがない場合、401を返す(get)
    it "returns 401 for index without Authorization header" do
      get "/api/v1/evaluations"
      expect(response).to have_http_status(:unauthorized)
    end

    # 共通系：Authorizationヘッダーがない場合、401を返す(post)
    it "returns 401 for create without Authorization header" do
      post "/api/v1/evaluations", params: { evaluation: { assignment_id: assignment.id, score: 3 } }
      expect(response).to have_http_status(:unauthorized)
    end

    # 共通系：Authorizationヘッダーがない場合、401を返す(patch)
    it "returns 401 for update without Authorization header" do
      patch "/api/v1/evaluations/#{evaluation.id}", params: { evaluation: { feedback: "x" } }
      expect(response).to have_http_status(:unauthorized)
    end

    # 共通系：Authorizationヘッダーがない場合、401を返す(delete)
    it "returns 401 for delete without Authorization header" do
      delete "/api/v1/evaluations/#{evaluation.id}"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/evaluations/:id" do
    # 正常系：グループメンバーとしてのアクセス
    it "shows evaluation if user is group member" do
      get "/api/v1/evaluations/#{evaluation.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(evaluation.id)
    end

    # 異常系：存在しない評価IDの場合、404を返す
    it "returns 404 if evaluation does not exist" do
      get "/api/v1/evaluations/99999999", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Evaluation with ID")
    end

    # 異常系：無効なID形式の場合、404を返す
    it "returns 404 with invalid id format" do
      get "/api/v1/evaluations/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Evaluation with ID")
    end

    # 異常系：グループ非メンバーの場合、403を返す
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_task = create(:task, group: other_group)
      other_membership = create(:membership, user: create(:user), group: other_group, role: 'member', active: true)
      other_assignment = create(:assignment, :completed, task: other_task, membership: other_membership, due_date: 2.days.ago, completed_date: 1.day.ago)
      other_evaluation = create(:evaluation, assignment: other_assignment, evaluator_id: other_membership.user.id)
      get "/api/v1/evaluations/#{other_evaluation.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/evaluations" do
    let!(:another_assignment) do
      # 既存のadminメンバーシップを使って同じグループ内の別アサインメントを作成
      create(:assignment, :completed, task: task, membership: admin_membership, due_date: 2.days.ago, completed_date: 1.day.ago)
    end
    let(:valid_params) do
      { evaluation: { assignment_id: another_assignment.id, score: 4, feedback: "good" } }
    end

    # 正常系：グループメンバーとしての評価作成
    it "creates evaluation if user is member" do
      expect {
        post "/api/v1/evaluations", params: valid_params, headers: headers
      }.to change(Evaluation, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["score"]).to eq(4)
    end

    # 異常系：パラメータ不正時に422を返す
    it "returns 422 if params invalid" do
      post "/api/v1/evaluations", params: { evaluation: { assignment_id: nil, score: nil } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
    end

    # 異常系：グループ非メンバーとしてのアクセス
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_task = create(:task, group: other_group)
      other_membership = create(:membership, user: create(:user), group: other_group, role: 'member', active: true, workload_ratio: 100)
      other_assignment = create(:assignment, :completed, task: other_task, membership: other_membership, due_date: 2.days.ago, completed_date: 1.day.ago)
      params = { evaluation: { assignment_id: other_assignment.id, score: 3, feedback: "test" } }
      post "/api/v1/evaluations", params: params, headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：スコアが最小値未満の場合に422を返す
    it "returns 422 when score is below minimum" do
      params = { evaluation: { assignment_id: another_assignment.id, score: 0 } }
      post "/api/v1/evaluations", params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Unprocessable Entity")
      expect(json["message"]).to eq("Validation failed")
      expect(json["errors"]).to include("Score must be greater than or equal to 1")
    end

    # 異常系：スコアが最大値超過の場合に422を返す
    it "returns 422 when score is not integer" do
      params = { evaluation: { assignment_id: another_assignment.id, score: 3.5 } }
      post "/api/v1/evaluations", params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Score must be an integer")
    end

    #異常系：フィードバックが最大文字数を超過する場合に422を返す
    it "returns 422 when feedback exceeds length" do
      params = { evaluation: { assignment_id: another_assignment.id, score: 3, feedback: "a" * 101 } }
      post "/api/v1/evaluations", params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Feedback is too long (maximum is 100 characters)")
    end

    #異常系：アサインメントが完了状態でない場合に422を返す
    it "returns 422 when assignment is not completed" do
      alt_task = create(:task, group: group)
      incomplete_assignment = create(:assignment, task: alt_task, membership: admin_membership, due_date: 2.days.from_now, status: "pending")
      params = { evaluation: { assignment_id: incomplete_assignment.id, score: 3, feedback: "test" } }
      post "/api/v1/evaluations", params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Assignment は完了状態でないと評価できません")
    end

    #異常系：同じ評価者による重複評価の場合に422を返す
    it "returns 422 for duplicate evaluation by same evaluator" do
      params = { evaluation: { assignment_id: assignment.id, score: 4, feedback: "dup" } }
      post "/api/v1/evaluations", params: params, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to include("Assignment は既に評価済みです")
    end
  end

  describe "PATCH /api/v1/evaluations/:id" do
    let(:update_params) { { evaluation: { feedback: "updated!" } } }

    # 正常系：グループメンバーとしての評価更新
    it "updates evaluation if user is member" do
      patch "/api/v1/evaluations/#{evaluation.id}", params: update_params, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["feedback"]).to eq("updated!")
    end

    # 異常系：存在しない評価IDの場合、404を返す
    it "returns 404 if evaluation does not exist" do
      patch "/api/v1/evaluations/99999999", params: { evaluation: { feedback: "x" } }, headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Evaluation with ID")
    end

    # 異常系：無効なID形式の場合、404を返す
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_task = create(:task, group: other_group)
      other_membership = create(:membership, user: create(:user), group: other_group, role: 'member', active: true, workload_ratio: 100)
      other_assignment = create(:assignment, :completed, task: other_task, membership: other_membership, due_date: 2.days.ago, completed_date: 1.day.ago)
      other_evaluation = create(:evaluation, assignment: other_assignment, evaluator_id: other_membership.user.id)
      patch "/api/v1/evaluations/#{other_evaluation.id}", params: { evaluation: { feedback: "x" } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/evaluations/:id" do
    # 正常系：グループ管理者としての評価削除
    it "deletes evaluation if user is admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
      evaluation_to_delete = create(:evaluation, assignment: assignment, evaluator_id: admin_user.id)
      expect {
        delete "/api/v1/evaluations/#{evaluation_to_delete.id}", headers: headers
      }.to change(Evaluation, :count).by(-1)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("successfully deleted")
    end

    # 異常系：グループ非メンバーとしてのアクセス
    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      evaluation_to_delete = create(:evaluation, assignment: assignment, evaluator_id: admin_user.id)
      delete "/api/v1/evaluations/#{evaluation_to_delete.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end

    # 異常系：存在しない評価IDの場合、404を返す
    it "returns 404 if evaluation does not exist" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
      delete "/api/v1/evaluations/99999999", headers: headers
      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("Evaluation with ID")
    end
  end
end
