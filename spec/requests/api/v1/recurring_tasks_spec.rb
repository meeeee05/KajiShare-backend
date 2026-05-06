require 'rails_helper'

RSpec.describe 'Api::V1::RecurringTasks', type: :request do
  let(:member_user) { create(:user) }
  let(:admin_user) { create(:user) }
  let(:outsider) { create(:user) }
  let(:group) { create(:group) }
  let(:headers) { { 'Authorization' => 'Bearer valid-token' } }
  let(:json) { JSON.parse(response.body) }

  before do
    allow_any_instance_of(ApplicationController)
      .to receive(:current_user)
      .and_return(member_user)

    allow_any_instance_of(Api::V1::RecurringTasksController)
      .to receive(:authenticate_user!)
      .and_return(true)
  end

  # 共通系：403 チェックの重複を減らす
  shared_examples 'forbidden' do
    it { expect(response).to have_http_status(:forbidden) }
  end

  # 正常系：メンバー権限があるならrecurring_tasksを取得できる
  describe 'GET /api/v1/groups/:group_id/recurring_tasks' do
    let!(:recurring_task) { create(:recurring_task, group: group, creator: admin_user) }

    context 'as group member' do
      it 'returns recurring tasks' do
        create(:membership, user: member_user, group: group, role: 'member', active: true, workload_ratio: 100)

        get "/api/v1/groups/#{group.id}/recurring_tasks", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json).to be_an(Array)
        expect(json.first['id']).to eq(recurring_task.id)
      end
    end

    context 'as non-member' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(outsider)

        get "/api/v1/groups/#{group.id}/recurring_tasks", headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end

  # 正常系：メンバー権限なら詳細1件を見られる
  describe 'GET /api/v1/recurring_tasks/:id' do
    let!(:recurring_task) { create(:recurring_task, group: group, creator: admin_user) }

    context 'as group member' do
      it 'returns a recurring task' do
        create(:membership, user: member_user, group: group, role: 'member', active: true, workload_ratio: 100)

        get "/api/v1/recurring_tasks/#{recurring_task.id}", headers: headers

        expect(response).to have_http_status(:ok)
        expect(json['id']).to eq(recurring_task.id)
      end
    end

    context 'as non-member' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(outsider)

        get "/api/v1/recurring_tasks/#{recurring_task.id}", headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end

  # 正常系：管理者権限があるならrecurring_tasksを作成できる
  describe 'POST /api/v1/groups/:group_id/recurring_tasks' do
    let(:valid_params) do
      {
        recurring_task: {
          name: 'Weekly Cleanup',
          description: '週次の掃除',
          point: 3,
          schedule_type: 'weekly',
          day_of_week: 2,
          starts_on: Date.current,
          active: true
        }
      }
    end

    context 'as admin' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(admin_user)

        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: 100)
      end

      it 'creates recurring task' do
        expect {
          post "/api/v1/groups/#{group.id}/recurring_tasks", params: valid_params, headers: headers
        }.to change(RecurringTask, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json['name']).to eq('Weekly Cleanup')
        expect(json['created_by_id']).to eq(admin_user.id)
      end

      # 正常系：無効なパラメータで作成しようとした場合、422を返す
      it 'returns 422 when params are invalid' do
        invalid_params = {
          recurring_task: {
            name: '',
            point: nil,
            schedule_type: 'weekly',
            day_of_week: nil,
            starts_on: nil
          }
        }

        post "/api/v1/groups/#{group.id}/recurring_tasks", params: invalid_params, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'as member (non-admin)' do
      before do
        create(:membership, user: member_user, group: group, role: 'member', active: true, workload_ratio: 100)

        post "/api/v1/groups/#{group.id}/recurring_tasks", params: valid_params, headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end

  # 正常系：管理者権限があるならrecurring_tasksを更新できる
  describe 'PATCH /api/v1/recurring_tasks/:id' do
    let!(:recurring_task) { create(:recurring_task, group: group, creator: admin_user) }

    context 'as admin' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(admin_user)

        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: 100)
      end

      it 'updates recurring task' do
        patch "/api/v1/recurring_tasks/#{recurring_task.id}",
              params: { recurring_task: { name: 'Updated Name' } },
              headers: headers

        expect(response).to have_http_status(:ok)
        expect(recurring_task.reload.name).to eq('Updated Name')
      end
    end

    context 'as member (non-admin)' do
      before do
        create(:membership, user: member_user, group: group, role: 'member', active: true, workload_ratio: 100)

        patch "/api/v1/recurring_tasks/#{recurring_task.id}",
              params: { recurring_task: { name: 'Updated Name' } },
              headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end

  # 正常系：管理者権限があるならrecurring_tasksを削除できる
  describe 'DELETE /api/v1/recurring_tasks/:id' do
    let!(:recurring_task) { create(:recurring_task, group: group, creator: admin_user) }

    context 'as admin' do
      before do
        allow_any_instance_of(ApplicationController)
          .to receive(:current_user)
          .and_return(admin_user)

        create(:membership, user: admin_user, group: group, role: 'admin', active: true, workload_ratio: 100)
      end

      it 'deletes recurring task' do
        expect {
          delete "/api/v1/recurring_tasks/#{recurring_task.id}", headers: headers
        }.to change(RecurringTask, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'as member (non-admin)' do
      before do
        create(:membership, user: member_user, group: group, role: 'member', active: true, workload_ratio: 100)

        delete "/api/v1/recurring_tasks/#{recurring_task.id}", headers: headers
      end

      it_behaves_like 'forbidden'
    end
  end
end