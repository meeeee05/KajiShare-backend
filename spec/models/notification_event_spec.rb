require 'rails_helper'

RSpec.describe Assignment, type: :model do
  describe 'task_assigned notification events' do
    let!(:group) { create(:group) }
    let!(:assignee_user) { create(:user) }
    let!(:other_user) { create(:user) }
    let!(:assignee_membership) { create(:membership, user: assignee_user, group: group, role: 'member', active: true, workload_ratio: 100) }
    let!(:other_membership) { create(:membership, user: other_user, group: group, role: 'member', active: true, workload_ratio: nil) }
    let!(:task) { create(:task, group: group) }

    it 'creates a task_assigned event on create' do
      expect do
        create(:assignment, task: task, membership: assignee_membership, assigned_by_id: other_user.id)
      end.to change(NotificationEvent, :count).by(1)

      event = NotificationEvent.order(:id).last
      expect(event.event_type).to eq('task_assigned')
      expect(event.recipient_user_id).to eq(assignee_user.id)
      expect(event.assignment_id).to be_present
      expect(event.task_id).to eq(task.id)
      expect(event.occurred_at).to be_present
    end

    it 'creates a task_assigned event on reassignment' do
      assignment = create(:assignment, task: task, membership: assignee_membership, assigned_by_id: other_user.id)

      expect do
        assignment.update!(membership: other_membership, assigned_by_id: assignee_user.id)
      end.to change(NotificationEvent, :count).by(1)

      event = NotificationEvent.order(:id).last
      expect(event.event_type).to eq('task_assigned')
      expect(event.recipient_user_id).to eq(other_user.id)
      expect(event.assignment_id).to eq(assignment.id)
      expect(event.task_id).to eq(task.id)
    end
  end
end
