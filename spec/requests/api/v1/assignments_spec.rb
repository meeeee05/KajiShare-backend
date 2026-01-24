# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::V1::Assignments", type: :request do
  let!(:group) { create(:group) }
  let!(:user) { create(:user) }
  let!(:admin_user) { create(:user) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true) }
  let!(:admin_membership) { create(:membership, user: admin_user, group: group, role: 'admin', active: true) }
  let!(:task) { create(:task, group: group) }
  let!(:assignment) { create(:assignment, task: task, membership: member_membership) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::AssignmentsController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/tasks/:task_id/assignments" do
    it "returns assignments for the task if user is member" do
      get "/api/v1/tasks/#{task.id}/assignments", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].first["id"].to_i).to eq(assignment.id)
    end
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_task = create(:task, group: other_group)
      get "/api/v1/tasks/#{other_task.id}/assignments", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
    it "returns 404 if task does not exist" do
      get "/api/v1/tasks/99999999/assignments", headers: headers
      expect(response).to have_http_status(:not_found)
    end
    it "returns 404 with invalid id format" do
      get "/api/v1/tasks/invalid_id/assignments", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/assignments/:id" do
    it "shows assignment if user is group member" do
      get "/api/v1/assignments/#{assignment.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(assignment.id)
    end
    it "returns 404 if assignment does not exist" do
      get "/api/v1/assignments/99999999", headers: headers
      expect(response).to have_http_status(:not_found)
    end
    it "returns 404 with invalid id format" do
      get "/api/v1/assignments/invalid_id", headers: headers
      expect(response).to have_http_status(:not_found)
    end
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_task = create(:task, group: other_group)
      other_membership = create(:membership, user: create(:user), group: other_group, role: 'member', active: true)
      other_assignment = create(:assignment, task: other_task, membership: other_membership)
      get "/api/v1/assignments/#{other_assignment.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/tasks/:task_id/assignments" do
    let(:valid_params) do
      { assignment: { due_date: Date.tomorrow, comment: "test" } }
    end
    it "creates assignment if user is member" do
      another_user = create(:user)
      another_membership = create(:membership, user: another_user, group: group, role: 'member', active: true)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(another_user)
      expect {
        post "/api/v1/tasks/#{task.id}/assignments", params: valid_params, headers: headers
      }.to change(Assignment, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["comment"]).to eq("test")
    end
    it "returns 422 if params invalid" do
      post "/api/v1/tasks/#{task.id}/assignments", params: { assignment: { due_date: nil } }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_present
    end
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_task = create(:task, group: other_group)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      post "/api/v1/tasks/#{other_task.id}/assignments", params: { assignment: { due_date: Date.tomorrow } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
    it "returns 404 if task does not exist" do
      post "/api/v1/tasks/99999999/assignments", params: { assignment: { due_date: Date.tomorrow } }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
    it "returns 404 with invalid id format" do
      post "/api/v1/tasks/invalid_id/assignments", params: { assignment: { due_date: Date.tomorrow } }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /api/v1/assignments/:id" do
    let(:update_params) { { assignment: { comment: "updated" } } }
    it "updates assignment if user is member" do
      patch "/api/v1/assignments/#{assignment.id}", params: update_params, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["comment"]).to eq("updated")
    end
    it "returns 404 if assignment does not exist" do
      patch "/api/v1/assignments/99999999", params: { assignment: { comment: "x" } }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
    it "returns forbidden if user is not group member" do
      other_group = create(:group)
      other_task = create(:task, group: other_group)
      other_membership = create(:membership, user: create(:user), group: other_group, role: 'member', active: true)
      other_assignment = create(:assignment, task: other_task, membership: other_membership)
      patch "/api/v1/assignments/#{other_assignment.id}", params: { assignment: { comment: "x" } }, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/assignments/:id" do
    it "deletes assignment if user is admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
      assignment_to_delete = create(:assignment, task: task, membership: admin_membership)
      expect {
        delete "/api/v1/assignments/#{assignment_to_delete.id}", headers: headers
      }.to change(Assignment, :count).by(-1)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("successfully deleted")
    end
    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      assignment_to_delete = create(:assignment, task: task, membership: admin_membership)
      delete "/api/v1/assignments/#{assignment_to_delete.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
    it "returns 404 if assignment does not exist" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
      delete "/api/v1/assignments/99999999", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
