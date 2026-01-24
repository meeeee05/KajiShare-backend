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
  end

  describe "GET /api/v1/assignments/:id" do
    it "shows assignment if user is group member" do
      get "/api/v1/assignments/#{assignment.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(assignment.id)
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
  end

  describe "PATCH /api/v1/assignments/:id" do
    let(:update_params) { { assignment: { comment: "updated" } } }
    it "updates assignment if user is member" do
      patch "/api/v1/assignments/#{assignment.id}", params: update_params, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["comment"]).to eq("updated")
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
  end
end
