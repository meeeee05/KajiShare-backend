# frozen_string_literal: true
require 'rails_helper'

RSpec.describe "Api::V1::Tasks", type: :request do
  let(:user) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:group) { create(:group) }
  let(:headers) { { "Authorization" => "Bearer valid-token" } }
  let(:json) { JSON.parse(response.body) }

  let!(:admin_membership) { create(:membership, user: admin_user, group: group, role: 'admin', active: true) }
  let!(:member_membership) { create(:membership, user: user, group: group, role: 'member', active: true) }
  let!(:task) { create(:task, group: group) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
    allow_any_instance_of(Api::V1::TasksController).to receive(:authenticate_user!).and_return(true)
  end

  shared_examples 'forbidden' do
    it { expect(response).to have_http_status(:forbidden) }
  end

  shared_examples 'not_found' do |msg|
    it do
      expect(response).to have_http_status(:not_found)
      expect(json["message"]).to include(msg)
    end
  end

  describe "GET /api/v1/groups/:group_id/tasks" do
    context "as group member" do
      it "returns tasks for group" do
        get "/api/v1/groups/#{group.id}/tasks", headers: headers
        expect(response).to have_http_status(:ok)
        expect(json).to have_key("data")
        expect(json["data"]).to be_an(Array)
        expect(json["data"].first["id"].to_i).to eq(task.id)
      end
    end

    context "as non-member" do
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user)) }
      it_behaves_like 'forbidden' do
        before { get "/api/v1/groups/#{group.id}/tasks", headers: headers }
      end
    end
  end

  describe "GET /api/v1/tasks/:id" do
    context "as group member" do
      it "shows task" do
        get "/api/v1/tasks/#{task.id}", headers: headers
        expect(response).to have_http_status(:ok)
        expect(json["data"]["id"].to_i).to eq(task.id)
        expect(json["data"]["attributes"]["name"]).to eq(task.name)
      end
    end

    context "as non-member" do
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user)) }
      it_behaves_like 'forbidden' do
        before { get "/api/v1/tasks/#{task.id}", headers: headers }
      end
    end
  end

  describe "POST /api/v1/groups/:group_id/tasks" do
    let(:valid_params) { { task: { name: "New Task", description: "desc", point: 10 } } }

    context "as group member" do
      it "creates task" do
        expect {
          post "/api/v1/groups/#{group.id}/tasks", params: valid_params, headers: headers
        }.to change(Task, :count).by(1)
        expect(response).to have_http_status(:created)
        expect(json["data"]["attributes"]["name"]).to eq("New Task")
      end

      it "returns error if params invalid" do
        post "/api/v1/groups/#{group.id}/tasks", params: { task: { name: "" } }, headers: headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "as non-member" do
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user)) }
      it_behaves_like 'forbidden' do
        before { post "/api/v1/groups/#{group.id}/tasks", params: valid_params, headers: headers }
      end
    end
  end

  describe "PATCH /api/v1/tasks/:id" do
    let(:update_params) { { task: { name: "Updated Task" } } }

    context "as group member" do
      it "updates task" do
        task = create(:task, group: group)
        patch "/api/v1/tasks/#{task.id}", params: update_params, headers: headers
        expect(response).to have_http_status(:ok)
        expect(json["data"]["attributes"]["name"]).to eq("Updated Task")
        expect(task.reload.name).to eq("Updated Task")
      end
    end

    context "as non-member" do
      it "returns forbidden" do
        task = create(:task, group: group)
        allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(create(:user))
        patch "/api/v1/tasks/#{task.id}", params: update_params, headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "task does not exist" do
      it_behaves_like 'not_found', 'Task with ID' do
        before { patch "/api/v1/tasks/99999999", params: update_params, headers: headers }
      end

      it_behaves_like 'not_found', 'Task with ID' do
        before { patch "/api/v1/tasks/invalid_id", params: update_params, headers: headers }
      end
    end
  end

  describe "DELETE /api/v1/tasks/:id" do
    context "as admin" do
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin_user) }
      it "deletes task" do
        task = create(:task, group: group)
        expect {
          delete "/api/v1/tasks/#{task.id}", headers: headers
        }.to change(Task, :count).by(-1)
        expect(response).to have_http_status(:ok)
        expect(json["message"]).to include("successfully deleted")
      end

      it_behaves_like 'not_found', 'Task with ID' do
        before { delete "/api/v1/tasks/99999999", headers: headers }
      end

      it_behaves_like 'not_found', 'Task with ID' do
        before { delete "/api/v1/tasks/invalid_id", headers: headers }
      end
    end

    context "as non-admin" do
      before { allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user) }
      it "returns forbidden" do
        task = create(:task, group: group)
        delete "/api/v1/tasks/#{task.id}", headers: headers
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
