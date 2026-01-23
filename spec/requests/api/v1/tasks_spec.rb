# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Api::V1::Tasks", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:group) { create(:group) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }

  let!(:admin_membership) { create(:membership, user: admin_user, group: group, role: 'admin', active: true) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true) }

  let!(:task) { create(:task, group: group) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::TasksController).to receive(:authenticate_user!).and_return(true)
  end

  describe "GET /api/v1/groups/:group_id/tasks" do
    it "returns tasks for group if user is member" do
      get "/api/v1/groups/#{group.id}/tasks", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to have_key("data")
      expect(json["data"]).to be_an(Array)
      expect(json["data"].first["id"].to_i).to eq(task.id)
    end

    it "returns forbidden if user is not member" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user))
      get "/api/v1/groups/#{group.id}/tasks", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/tasks/:id" do
    it "shows task if user is group member" do
      get "/api/v1/tasks/#{task.id}", headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["id"].to_i).to eq(task.id)
      expect(json["data"]["attributes"]["name"]).to eq(task.name)
    end

    it "returns forbidden if user is not group member" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user))
      get "/api/v1/tasks/#{task.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/groups/:group_id/tasks" do
    let(:valid_params) do
      { task: { name: "New Task", description: "desc", point: 10 } }
    end

    it "creates task if user is member" do
      expect {
        post "/api/v1/groups/#{group.id}/tasks", params: valid_params, headers: headers
      }.to change(Task, :count).by(1)
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["name"]).to eq("New Task")
    end

    it "returns error if params invalid" do
      post "/api/v1/groups/#{group.id}/tasks", params: { task: { name: "" } }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns forbidden if not group member" do
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user))
      post "/api/v1/groups/#{group.id}/tasks", params: valid_params, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    let(:update_params) { { task: { name: "Updated Task" } } }

    it "updates task if user is member" do
      task = create(:task, group: group)
      patch "/api/v1/tasks/#{task.id}", params: update_params, headers: headers
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["data"]["attributes"]["name"]).to eq("Updated Task")
      expect(task.reload.name).to eq("Updated Task")
    end

    it "returns forbidden if not group member" do
      task = create(:task, group: group)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user))
      patch "/api/v1/tasks/#{task.id}", params: update_params, headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    it "deletes task if user is admin" do
      task = create(:task, group: group)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user)
      expect {
        delete "/api/v1/tasks/#{task.id}", headers: headers
      }.to change(Task, :count).by(-1)
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["message"]).to include("successfully deleted")
    end

    it "returns forbidden if not admin" do
      task = create(:task, group: group)
      allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
      delete "/api/v1/tasks/#{task.id}", headers: headers
      expect(response).to have_http_status(:forbidden)
    end
  end
end
