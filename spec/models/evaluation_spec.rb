# spec/models/evaluation_spec.rb
require 'rails_helper'

# Evaluationモデル関連付けテスト
RSpec.describe Evaluation, type: :model do
  describe 'associations' do
    it { should belong_to(:assignment) }
    it { should belong_to(:evaluator).class_name('User').with_foreign_key('evaluator_id') }
  end

  # shoulda-matchersで宣言的に網羅（入力値検証）
  describe 'validations' do
    subject { build(:evaluation) }

    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }
    let(:assignment) { create(:assignment, :completed, membership: membership, task: task, due_date: Date.yesterday, completed_date: Date.current) }
    let(:evaluator) { create(:user) }

    # 重複評価防止のため、既存の評価を作成
    before do
      create(:evaluation, assignment: assignment, evaluator: evaluator)
    end

    # 正常系：scoreは必ず1〜5の整数
    it { should validate_presence_of(:score) }
    it do
      should validate_numericality_of(:score)
        .only_integer
        .is_greater_than_or_equal_to(1)
        .is_less_than_or_equal_to(5)
    end

    # 正常系：feedbackは100文字以内
    it { should validate_length_of(:feedback).is_at_most(100) }

    # 異常系：同じ課題・同じ評価者で2つ目の評価を作成できない
    it do
      should validate_uniqueness_of(:assignment_id)
        .scoped_to(:evaluator_id)
        .with_message('は既に評価済みです')
    end
  end

  # テストデータ作成
  describe 'custom validations' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }
    let(:evaluator) { create(:user) }

    # 異常系：未完了の課題には評価をつけられない
    it 'is invalid if assignment is not completed' do
      pending_assignment = create(
        :assignment,
        membership: membership,
        task: task,
        status: 'pending'
      )

      evaluation = build(
        :evaluation,
        assignment: pending_assignment,
        evaluator: evaluator
      )

      expect(evaluation).not_to be_valid
      expect(evaluation.errors[:assignment])
        .to include('は完了状態でないと評価できません')
    end
  end

  # 正常系：evaluationを正しく作成できる
  describe 'factory' do
    it 'creates a valid evaluation' do
      expect(create(:evaluation)).to be_valid
    end
  end
end