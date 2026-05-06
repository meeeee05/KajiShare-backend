require 'rails_helper'
# NotificationEventモデル関連付け
RSpec.describe NotificationEvent, type: :model do
  describe 'associations' do
    it { should belong_to(:recipient_user).class_name('User').with_foreign_key('recipient_user_id') }
    it { should belong_to(:actor_user).class_name('User').with_foreign_key('actor_user_id').optional }
    it { should belong_to(:group).optional }
    it { should belong_to(:task).optional }
    it { should belong_to(:assignment).optional }
  end

  # 正常系：入力値検証（以下3項目が未記入であれば通知しない）
  describe 'validations' do
    subject { build(:notification_event) }

    it { should validate_presence_of(:event_type) }
    it { should validate_presence_of(:recipient_user_id) }
    it { should validate_presence_of(:occurred_at) }
  end

  #　正常系：通知作成
  describe 'scopes' do
    it 'returns only task_assigned events' do
      matched = create(:notification_event, event_type: 'task_assigned')
      create(:notification_event, event_type: 'task_evaluated')

      expect(NotificationEvent.task_assigned).to contain_exactly(matched)
    end
  end

  # 正常系：有効なNotificationEventが作成できることを確認
  describe 'factory' do
    it 'creates a valid notification event' do
      expect(create(:notification_event)).to be_valid
    end
  end

  # 正常系：assignmentからのtask_assignedイベントの作成を確認
  describe 'task_assigned notification events from assignment' do
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
