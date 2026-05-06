require 'rails_helper'
# RecurringTaskモデル関連付け
RSpec.describe RecurringTask, type: :model do
  describe 'associations' do
    it { should belong_to(:group) }
    it { should belong_to(:creator).class_name('User').with_foreign_key('created_by_id') }
    it { should have_many(:tasks).with_foreign_key('source_recurring_task_id').dependent(:nullify) }
  end

  # 正常系：不正な入力を保存させない（入力値検証）
  describe 'validations' do
    subject { build(:recurring_task) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }

    it { should validate_presence_of(:point) }
    it do
      should validate_numericality_of(:point)
        .only_integer
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(5)
    end

    it { should validate_presence_of(:starts_on) }

    it 'is invalid when day_of_week is missing for weekly schedule' do
      recurring_task = build(:recurring_task, schedule_type: 'weekly', day_of_week: nil)

      expect(recurring_task).not_to be_valid
      expect(recurring_task.errors[:day_of_week]).to include("can't be blank")
    end

    it 'is invalid when day_of_week is out of range' do
      recurring_task = build(:recurring_task, schedule_type: 'weekly', day_of_week: 7)

      expect(recurring_task).not_to be_valid
      expect(recurring_task.errors[:day_of_week]).to include('is not included in the list')
    end
  end

  # 正常系：有効なRecurringTaskが作成できることを確認
  describe 'factory' do
    it 'creates a valid recurring task' do
      expect(create(:recurring_task)).to be_valid
    end
  end

  # 正常系：定期タスクを削除したとき、紐づくタスクを削除しない
  describe 'dependent nullify' do
    it 'nullifies source_recurring_task_id on tasks when recurring task is destroyed' do
      recurring_task = create(:recurring_task)
      task = create(:task, group: recurring_task.group, source_recurring_task_id: recurring_task.id)

      expect { recurring_task.destroy }.not_to change(Task, :count)
      expect(task.reload.source_recurring_task_id).to be_nil
    end
  end
end