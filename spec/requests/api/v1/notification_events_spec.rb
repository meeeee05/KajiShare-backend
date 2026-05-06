require 'rails_helper'

RSpec.describe 'Api::V1::NotificationEvents', type: :request do
  let!(:group) { create(:group) }
  let!(:actor) { create(:user) }
  let!(:assignee) { create(:user) }
  let!(:actor_membership) { create(:membership, user: actor, group: group, role: 'admin', active: true, workload_ratio: 100) }
  let!(:assignee_membership) { create(:membership, user: assignee, group: group, role: 'member', active: true, workload_ratio: nil) }
  let!(:task) { create(:task, group: group) }
  let!(:task2) { create(:task, group: group) }
  let(:headers) { { 'Authorization' => 'Bearer test-token' } }

  before do
    allow_any_instance_of(Api::V1::AssignmentsController).to receive(:authenticate_user!).and_return(true)
    allow_any_instance_of(Api::V1::NotificationEventsController).to receive(:authenticate_user!).and_return(true)
  end

  def set_current_user(user)
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  def response_json
    JSON.parse(response.body)
  end

  def notifications
    response_json.dig('data', 'notifications') || []
  end

  # 共通系：認証なしでアクセスした場合、401を返す
  describe 'Authentication' do
    before do
      allow_any_instance_of(Api::V1::NotificationEventsController)
        .to receive(:authenticate_user!)
        .and_call_original
      allow_any_instance_of(ApplicationController)
        .to receive(:current_user)
        .and_call_original
    end

    it 'returns 401 without Authorization header' do
      get '/api/v1/notifications'
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # 正常系：assignment作成・更新時のtask_assignedイベントの作成と通知の取得を確認
  it 'returns task_assigned notification for assignee after assignment create' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'notify check' } },
         headers: headers

    expect(response).to have_http_status(:created)
    created_assignment_id = response_json.dig('data', 'id').to_i

    set_current_user(assignee)

    get '/api/v1/notifications', params: { limit: 100 }, headers: headers
    expect(response).to have_http_status(:ok)

    body = response_json
    expect(body.dig('data', 'viewer_user_id')).to eq(assignee.id)
    expect(body.dig('data', 'viewer_google_sub')).to eq(assignee.google_sub)
    task_assigned = (body.dig('data', 'notifications') || []).find do |item|
      item['type'] == 'task_assigned' && item['assignment_id'].to_i == created_assignment_id
    end

    expect(task_assigned).to be_present
    expect(task_assigned['task_id'].to_i).to eq(task.id)
    expect(task_assigned['occurred_at']).to be_present
  end

  # 正常系：同一assignmentに対する複数のtask_assignedイベントの作成と取得を確認
  it 'creates a new task_assigned event on second assign operation for same assignment' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'first assign' } },
         headers: headers
    expect(response).to have_http_status(:created)

    assignment_id = response_json.dig('data', 'id').to_i
    first_event_count = NotificationEvent.where(event_type: 'task_assigned', assignment_id: assignment_id).count

    patch "/api/v1/assignments/#{assignment_id}",
          params: { assignment: { membership_id: assignee_membership.id, comment: 'second assign' } },
          headers: headers
    expect(response).to have_http_status(:ok)

    second_event_count = NotificationEvent.where(event_type: 'task_assigned', assignment_id: assignment_id).count
    expect(second_event_count).to eq(first_event_count + 1)
  end

  # 正常系：前回以降に増えた通知だけ取得できることを確認
  it 'returns all increased task_assigned notifications with since_id' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'first' } },
         headers: headers
    expect(response).to have_http_status(:created)

    set_current_user(assignee)
    get '/api/v1/notifications', params: { limit: 100 }, headers: headers
    expect(response).to have_http_status(:ok)

    initial = notifications
    latest_task_assigned = initial.find { |item| item['type'] == 'task_assigned' }
    expect(latest_task_assigned).to be_present

    since_id = latest_task_assigned['id'].to_s.split('_').last.to_i
    expect(since_id).to be > 0

    set_current_user(actor)
    post "/api/v1/tasks/#{task2.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'second' } },
         headers: headers
    expect(response).to have_http_status(:created)

    patch "/api/v1/assignments/#{response_json.dig('data', 'id')}",
          params: { assignment: { membership_id: assignee_membership.id, comment: 'third' } },
          headers: headers
    expect(response).to have_http_status(:ok)

    set_current_user(assignee)
    get '/api/v1/notifications', params: { limit: 100, since_id: since_id }, headers: headers
    expect(response).to have_http_status(:ok)

    increased = notifications
      .select { |item| item['type'] == 'task_assigned' }

    expect(increased.size).to be >= 2
  end

  # 正常系：type=task_assignedを利用して通知を取得できることを確認
  it 'supports task_assigned only mode for records page' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'records target' } },
         headers: headers
    expect(response).to have_http_status(:created)

    set_current_user(assignee)
    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned' }, headers: headers
    expect(response).to have_http_status(:ok)

    expect(notifications).to all(include('type' => 'task_assigned'))
  end

  # 正常系：通知内容表示用の内容がレスポンスに含まれていることを確認
  it 'returns records mode metadata and latest cursor for records page polling' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'cursor check' } },
         headers: headers
    expect(response).to have_http_status(:created)

    set_current_user(assignee)
    get '/api/v1/notifications', params: { limit: 100, for_records: true }, headers: headers
    expect(response).to have_http_status(:ok)

    data = response_json.fetch('data')
    expect(data['mode']).to eq('records')
    expect(data['latest_task_assigned_event_id']).to be_present
    expect(data['server_time']).to be_present
    expect((data['notifications'] || []).all? { |n| n['type'] == 'task_assigned' }).to be(true)
  end

  # 正常系：since_idにtask_assigned_idを指定して、取得できることを確認
  it 'accepts prefixed since_id like task_assigned_12' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'prefixed since first' } },
         headers: headers
    expect(response).to have_http_status(:created)

    post "/api/v1/tasks/#{task2.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'prefixed since second' } },
         headers: headers
    expect(response).to have_http_status(:created)

    set_current_user(assignee)
    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned' }, headers: headers
    expect(response).to have_http_status(:ok)

    all_notifications = notifications
    newest = all_notifications.first
    expect(newest).to be_present

    prefixed_since_id = newest['id']
    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned', since_id: prefixed_since_id }, headers: headers
    expect(response).to have_http_status(:ok)

    filtered = notifications
    expect(filtered.map { |n| n['id'] }).not_to include(prefixed_since_id)
  end

  # 異常系：無効なidは無視されることを確認
  it 'ignores invalid since_id token like abc' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'invalid since token' } },
         headers: headers
    expect(response).to have_http_status(:created)

    set_current_user(assignee)

    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned' }, headers: headers
    expect(response).to have_http_status(:ok)
    normal = notifications

    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned', since_id: 'abc' }, headers: headers
    expect(response).to have_http_status(:ok)
    invalid_since = notifications

    expect(invalid_since.map { |n| n['id'] }).to eq(normal.map { |n| n['id'] })
  end

  # 異常系：idが0以下の場合は無視され、通常取得になることを確認
  it 'ignores non-positive since_id' do
    set_current_user(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'non positive since id' } },
         headers: headers
    expect(response).to have_http_status(:created)

    set_current_user(assignee)

    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned' }, headers: headers
    expect(response).to have_http_status(:ok)
    normal = notifications

    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned', since_id: 0 }, headers: headers
    expect(response).to have_http_status(:ok)
    zero_since = notifications

    expect(zero_since.map { |n| n['id'] }).to eq(normal.map { |n| n['id'] })
  end

  # 異常系：返ってきた通知の中に member_joined が含まれるかを確認
  it 'falls back to default notifications when type is unknown' do
    set_current_user(assignee)

    get '/api/v1/notifications', params: { limit: 100, type: 'unknown_type' }, headers: headers
    expect(response).to have_http_status(:ok)

    types = notifications.map { |item| item['type'] }
    expect(types).to include('member_joined')
  end
end
