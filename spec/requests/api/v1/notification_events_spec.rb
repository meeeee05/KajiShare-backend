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

  it 'returns task_assigned notification for assignee after assignment create' do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'notify check' } },
         headers: headers

    expect(response).to have_http_status(:created)
    created_assignment_id = JSON.parse(response.body).dig('data', 'id').to_i

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(assignee)

    get '/api/v1/notifications', params: { limit: 100 }, headers: headers
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)
    expect(body.dig('data', 'viewer_user_id')).to eq(assignee.id)
    expect(body.dig('data', 'viewer_google_sub')).to eq(assignee.google_sub)
    notifications = body.dig('data', 'notifications') || []
    task_assigned = notifications.find do |item|
      item['type'] == 'task_assigned' && item['assignment_id'].to_i == created_assignment_id
    end

    expect(task_assigned).to be_present
    expect(task_assigned['task_id'].to_i).to eq(task.id)
    expect(task_assigned['occurred_at']).to be_present
  end

  it 'creates a new task_assigned event on second assign operation for same assignment' do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'first assign' } },
         headers: headers
    expect(response).to have_http_status(:created)

    assignment_id = JSON.parse(response.body).dig('data', 'id').to_i
    first_event_count = NotificationEvent.where(event_type: 'task_assigned', assignment_id: assignment_id).count

    patch "/api/v1/assignments/#{assignment_id}",
          params: { assignment: { membership_id: assignee_membership.id, comment: 'second assign' } },
          headers: headers
    expect(response).to have_http_status(:ok)

    second_event_count = NotificationEvent.where(event_type: 'task_assigned', assignment_id: assignment_id).count
    expect(second_event_count).to eq(first_event_count + 1)
  end

  it 'returns all increased task_assigned notifications with since_id' do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'first' } },
         headers: headers
    expect(response).to have_http_status(:created)

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(assignee)
    get '/api/v1/notifications', params: { limit: 100 }, headers: headers
    expect(response).to have_http_status(:ok)

    initial = JSON.parse(response.body).dig('data', 'notifications') || []
    latest_task_assigned = initial.find { |item| item['type'] == 'task_assigned' }
    expect(latest_task_assigned).to be_present

    since_id = latest_task_assigned['id'].to_s.split('_').last.to_i
    expect(since_id).to be > 0

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(actor)
    post "/api/v1/tasks/#{task2.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'second' } },
         headers: headers
    expect(response).to have_http_status(:created)

    patch "/api/v1/assignments/#{JSON.parse(response.body).dig('data', 'id')}",
          params: { assignment: { membership_id: assignee_membership.id, comment: 'third' } },
          headers: headers
    expect(response).to have_http_status(:ok)

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(assignee)
    get '/api/v1/notifications', params: { limit: 100, since_id: since_id }, headers: headers
    expect(response).to have_http_status(:ok)

    increased = (JSON.parse(response.body).dig('data', 'notifications') || [])
      .select { |item| item['type'] == 'task_assigned' }

    expect(increased.size).to be >= 2
  end

  it 'supports task_assigned only mode for records page' do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'records target' } },
         headers: headers
    expect(response).to have_http_status(:created)

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(assignee)
    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned' }, headers: headers
    expect(response).to have_http_status(:ok)

    notifications = JSON.parse(response.body).dig('data', 'notifications') || []
    expect(notifications).to all(include('type' => 'task_assigned'))
  end

  it 'returns records mode metadata and latest cursor for records page polling' do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'cursor check' } },
         headers: headers
    expect(response).to have_http_status(:created)

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(assignee)
    get '/api/v1/notifications', params: { limit: 100, for_records: true }, headers: headers
    expect(response).to have_http_status(:ok)

    data = JSON.parse(response.body).fetch('data')
    expect(data['mode']).to eq('records')
    expect(data['latest_task_assigned_event_id']).to be_present
    expect(data['server_time']).to be_present
    expect((data['notifications'] || []).all? { |n| n['type'] == 'task_assigned' }).to be(true)
  end

  it 'accepts prefixed since_id like task_assigned_12' do
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(actor)

    post "/api/v1/tasks/#{task.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'prefixed since first' } },
         headers: headers
    expect(response).to have_http_status(:created)

    post "/api/v1/tasks/#{task2.id}/assignments",
         params: { assignment: { membership_id: assignee_membership.id, due_date: Date.tomorrow, comment: 'prefixed since second' } },
         headers: headers
    expect(response).to have_http_status(:created)

    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(assignee)
    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned' }, headers: headers
    expect(response).to have_http_status(:ok)

    all_notifications = JSON.parse(response.body).dig('data', 'notifications') || []
    newest = all_notifications.first
    expect(newest).to be_present

    prefixed_since_id = newest['id']
    get '/api/v1/notifications', params: { limit: 100, type: 'task_assigned', since_id: prefixed_since_id }, headers: headers
    expect(response).to have_http_status(:ok)

    filtered = JSON.parse(response.body).dig('data', 'notifications') || []
    expect(filtered.map { |n| n['id'] }).not_to include(prefixed_since_id)
  end
end
