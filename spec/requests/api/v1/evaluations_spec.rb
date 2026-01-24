# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::V1::Evaluations", type: :request do
  let!(:group) { create(:group) }
  let!(:user) { create(:user) }
  let!(:admin_user) { create(:user) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true) }
  let!(:admin_membership) { create(:membership, user: admin_user, group: group, role: 'admin', active: true) }
  let!(:task) { create(:task, group: group) }
  let!(:assignment) { create(:assignment, :completed, task: task, membership: member_membership, due_date: 2.days.ago, completed_date: 1.day.ago) }
  let!(:evaluation) { create(:evaluation, assignment: assignment, evaluator_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::EvaluationsController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/evaluations" do
    it "returns evaluations for groups user belongs to" do
      get "/api/v1/evaluations", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].map { |e| e["id"].to_i }).to include(evaluation.id)
    end
  end

  describe "GET /api/v1/evaluations/:id" do
    it "shows evaluation if user is group member" do
      get "/api/v1/evaluations/#{evaluation.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(evaluation.id)
    end
  end

  describe "POST /api/v1/evaluations" do
    let!(:another_assignment) do
      another_membership = create(:membership, user: create(:user), group: group, role: 'member', active: true)
      create(:assignment, :completed, task: task, membership: another_membership, due_date: 2.days.ago, completed_date: 1.day.ago)
    end
    let(:valid_params) do
      { evaluation: { assignment_id: another_assignment.id, score: 4, feedback: "good" } }
    end
    it "creates evaluation if user is member" do
      expect {
        post "/api/v1/evaluations", params: valid_params, headers: headers
      }.to change(Evaluation, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["score"]).to eq(4)
    end
  end

  describe "PATCH /api/v1/evaluations/:id" do
    let(:update_params) { { evaluation: { feedback: "updated!" } } }
    it "updates evaluation if user is member" do
      patch "/api/v1/evaluations/#{evaluation.id}", params: update_params, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["feedback"]).to eq("updated!")
    end
  end

  describe "DELETE /api/v1/evaluations/:id" do
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
    it "returns forbidden if not admin" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      evaluation_to_delete = create(:evaluation, assignment: assignment, evaluator_id: admin_user.id)
      delete "/api/v1/evaluations/#{evaluation_to_delete.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
