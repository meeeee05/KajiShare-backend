require 'rails_helper'

# Assignmentモデル関連付けテスト
RSpec.describe Assignment, type: :model do
  describe 'associations' do
    it { should belong_to(:task) }
    it { should belong_to(:membership) }
    it { should have_many(:evaluations).dependent(:destroy) }
  end

  # shoulda-matchersで宣言的に網羅（入力値検証）
  describe 'validations' do
    subject { build(:assignment) }
    # belongs_toで十分なのでpresence_ofは削除
    it { should belong_to(:task) }
    it { should belong_to(:membership) }
  end

  # 異常系：入力値検証
  describe 'invalid validations' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }

    # 異常系：完了日がnilの場合評価できない
    it 'is invalid if completed_date is nil when status is completed' do
      assignment = build(:assignment, task: task, membership: membership, status: 'completed', due_date: Date.current, completed_date: nil)
      expect(assignment).not_to be_valid
      expect(assignment.errors[:completed_date]).to include("can't be blank")
    end

    # 異常系：完了日は必ず期限日と同じか、それ以降でなければ評価できない
    it 'is invalid if completed_date is before due_date' do
      assignment = build(:assignment, task: task, membership: membership, status: 'completed', due_date: Date.current, completed_date: Date.yesterday)
      expect(assignment).not_to be_valid
      expect(assignment.errors[:completed_date]).to include('は期限日以降である必要があります')
    end

    # 異常系：同じ課題にはAssignmentを重複して作成できない
    it 'is invalid with duplicate task for same user' do
      create(:assignment, task: task, membership: membership)
      duplicate = build(:assignment, task: task, membership: membership)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to include('同じtask_idのタスクを同じユーザーに重複して割り当てることはできません')
    end

    # 異常系：同じ課題を別ユーザーに重複して作成できない
    it 'is invalid with duplicate task for another user' do
      create(:assignment, task: task, membership: membership)
      other_membership = create(:membership, group: membership.group, workload_ratio: nil)
      duplicate = build(:assignment, task: task, membership: other_membership)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to include('このタスクはすでに別のユーザーに割り当て済みです')
    end
  end

  # 正常系：enumの値の制限が範囲内
  describe 'enums' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }
    it 'accepts valid status values' do
      assignment = build(:assignment, task: task, membership: membership, status: 'not_started')
      expect(assignment).to be_valid
      assignment.status = 'in_progress'
      expect(assignment).to be_valid
      assignment.status = 'completed'
      assignment.due_date = Date.yesterday
      assignment.completed_date = Date.current
      expect(assignment).to be_valid
    end

    # 異常系：無効なenum値はエラーになる
    it 'sets completed_by_user_id when completed_date is present' do
      assignment = create(:assignment, task: task, membership: membership, due_date: Date.yesterday, completed_date: Date.current)
      expect(assignment.completed_by_user_id).to eq(membership.user_id)
    end
  end

  # 正常系：evaluationを正しく作成できる
  describe 'factory' do
    it 'creates a valid assignment' do
      expect(create(:assignment)).to be_valid
    end
  end

  # 正常系：assignmentに紐づく先も一緒に削除される
  describe 'dependent destroy' do
    it 'destroys associated evaluations when assignment is destroyed' do
      assignment = create(:assignment, :completed, due_date: Date.yesterday)
      evaluation = create(:evaluation, assignment: assignment)
      expect { assignment.destroy }.to change { Evaluation.count }.by(-1)
    end
  end
end
