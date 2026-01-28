# frozen_string_literal: true
require 'rails_helper'

let(:json_response) { JSON.parse(response.body) }

RSpec.describe "Api::V1::Assignments", type: :request do
  let!(:group) { create(:group) }
  let!(:user) { create(:user) }
  let!(:admin_user) { create(:user) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true, workload_ratio: 100) }
  # admin_membershipは必要なテスト内で個別に作成
  let!(:task) { create(:task, group: group) }
  let!(:assignment) { create(:assignment, task: task, membership: member_membership) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::AssignmentsController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/tasks/:task_id/assignments" do
    subject { get "/api/v1/tasks/#{task_id}/assignments", headers: headers }

    context "when user is member" do
      let(:task_id) { task.id }
      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response["data"]).to be_an(Array)
        expect(json_response["data"].first["id"].to_i).to eq(assignment.id)
      end
    end

    context "when user is not group member" do
      let(:other_group) { create(:group) }
      let(:task_id) { create(:task, group: other_group).id }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when task does not exist" do
      let(:task_id) { 99999999 }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

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

    context "when user is group member" do
      let(:assignment_id) { assignment.id }
      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response["data"]["id"].to_i).to eq(assignment.id)
      end
    end
    context "when assignment does not exist" do
      let(:assignment_id) { 99999999 }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
    context "when id format is invalid" do
      let(:assignment_id) { 'invalid_id' }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
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
    let(:valid_params) { { assignment: { due_date: Date.tomorrow, comment: "test" } } }
    subject { post "/api/v1/tasks/#{task_id}/assignments", params: params, headers: headers }

    context "when user is member" do
      let(:task_id) { task.id }
      let(:params) { valid_params }
      it "creates assignment" do
        another_user = create(:user)
        member_membership.destroy # 既存のmembershipを削除し、合計100を担保
        create(:membership, user: another_user, group: group, role: 'member', active: true, workload_ratio: 100)
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(another_user)
        expect { post "/api/v1/tasks/#{task.id}/assignments", params: valid_params, headers: headers }.to change(Assignment, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(json_response["data"]["attributes"]["comment"]).to eq("test")
      end
    end

    context "when params invalid" do
      let(:task_id) { task.id }
      let(:params) { { assignment: { due_date: nil } } }
      it do
        subject
        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response["errors"]).to be_present
      end
    end

    context "when user is not group member" do
      let(:other_group) { create(:group) }
      let(:task_id) { create(:task, group: other_group).id }
      let(:params) { { assignment: { due_date: Date.tomorrow } } }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "when task does not exist" do
      let(:task_id) { 99999999 }
      let(:params) { { assignment: { due_date: Date.tomorrow } } }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end

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
    let(:update_params) { { assignment: { comment: "updated" } } }
    subject { patch "/api/v1/assignments/#{assignment_id}", params: params, headers: headers }

    context "when user is member" do
      let(:assignment_id) { assignment.id }
      let(:params) { update_params }
      it do
        subject
        expect(response).to have_http_status(:ok)
        expect(json_response["data"]["attributes"]["comment"]).to eq("updated")
      end
    end
    context "when assignment does not exist" do
      let(:assignment_id) { 99999999 }
      let(:params) { { assignment: { comment: "x" } } }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
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

    context "when user is admin" do
      let!(:admin_membership) do
        member_membership.destroy # 既存のmembershipを削除し、合計100を担保
        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: 100)
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
    context "when not admin" do
      let!(:admin_membership) do
        member_membership.destroy # 既存のmembershipを削除し、合計100を担保
        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: 100)
      end
      let(:assignment_id) { create(:assignment, task: task, membership: admin_membership).id }
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user) }
      it do
        subject
        expect(response).to have_http_status(:forbidden)
      end
    end
    context "when assignment does not exist" do
      let(:assignment_id) { 99999999 }
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user) }
      it do
        subject
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
