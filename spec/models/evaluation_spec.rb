require 'rails_helper'

RSpec.describe Evaluation, type: :model do
  describe 'associations' do
    it { should belong_to(:assignment) }
    it { should belong_to(:evaluator).class_name('User').with_foreign_key('evaluator_id') }
  end

  describe 'validations' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }
    let(:completed_assignment) { create(:assignment, :completed, membership: membership, task: task, due_date: Date.yesterday) }
    let(:evaluator) { create(:user) }

    describe 'score validation' do
      it 'requires score to be present' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: nil)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:score]).to include("can't be blank")
      end

      it 'accepts score of 1' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 1)
        expect(evaluation).to be_valid
      end

      it 'accepts score of 5' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 5)
        expect(evaluation).to be_valid
      end

      it 'accepts score of 3' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 3)
        expect(evaluation).to be_valid
      end

      it 'rejects score less than 1' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 0)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:score]).to include("must be greater than or equal to 1")
      end

      it 'rejects score greater than 5' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 6)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:score]).to include("must be less than or equal to 5")
      end

      it 'rejects non-integer score' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 3.5)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:score]).to include("must be an integer")
      end
    end

    describe 'feedback validation' do
      it 'allows blank feedback' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, feedback: '')
        expect(evaluation).to be_valid
      end

      it 'allows nil feedback' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, feedback: nil)
        expect(evaluation).to be_valid
      end

      it 'allows feedback up to 100 characters' do
        feedback = 'a' * 100
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, feedback: feedback)
        expect(evaluation).to be_valid
      end

      it 'rejects feedback longer than 100 characters' do
        feedback = 'a' * 101
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, feedback: feedback)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:feedback]).to include("is too long (maximum is 100 characters)")
      end

      it 'allows feedback with Japanese characters' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, feedback: 'とても良い仕事でした！')
        expect(evaluation).to be_valid
      end
    end

    describe 'uniqueness validation' do
      before do
        create(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 4)
      end

      it 'prevents duplicate evaluation by same evaluator for same assignment' do
        duplicate_evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator, score: 5)
        expect(duplicate_evaluation).not_to be_valid
        expect(duplicate_evaluation.errors[:assignment_id]).to include("は既に評価済みです")
      end

      it 'allows same evaluator to evaluate different assignments' do
        membership2 = create(:membership, group: task.group)
        assignment2 = create(:assignment, :completed, membership: membership2, task: task, due_date: Date.yesterday)
        evaluation2 = build(:evaluation, assignment: assignment2, evaluator: evaluator, score: 5)
        expect(evaluation2).to be_valid
      end

      it 'allows different evaluators to evaluate same assignment' do
        evaluator2 = create(:user)
        evaluation2 = build(:evaluation, assignment: completed_assignment, evaluator: evaluator2, score: 5)
        expect(evaluation2).to be_valid
      end
    end

    describe 'assignment completion validation' do
      it 'allows evaluation of completed assignment' do
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator)
        expect(evaluation).to be_valid
      end

      it 'prevents evaluation of pending assignment' do
        pending_assignment = create(:assignment, membership: membership, task: task, status: 'pending')
        evaluation = build(:evaluation, assignment: pending_assignment, evaluator: evaluator)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:assignment]).to include("は完了状態でないと評価できません")
      end

      it 'prevents evaluation of in_progress assignment' do
        in_progress_assignment = create(:assignment, membership: membership, task: task, status: 'in_progress')
        evaluation = build(:evaluation, assignment: in_progress_assignment, evaluator: evaluator)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:assignment]).to include("は完了状態でないと評価できません")
      end

      it 'handles nil assignment gracefully' do
        evaluation = build(:evaluation, assignment: nil, evaluator: evaluator)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:assignment]).to include("must exist")
      end
    end
  end

  describe 'factory' do
    it 'creates valid evaluation' do
      evaluation = create(:evaluation)
      expect(evaluation).to be_valid
      expect(evaluation.score).to eq(5)
      expect(evaluation.feedback).to eq("Great job!")
      expect(evaluation.assignment.completed?).to be true
      expect(evaluation.evaluator).to be_present
    end

    it 'creates evaluation with custom attributes' do
      evaluator = create(:user)
      membership = create(:membership)
      task = create(:task, group: membership.group)
      assignment = create(:assignment, :completed, membership: membership, task: task, due_date: Date.yesterday)
      
      evaluation = create(:evaluation, 
        assignment: assignment, 
        evaluator: evaluator, 
        score: 3, 
        feedback: "Needs improvement"
      )
      expect(evaluation).to be_valid
      expect(evaluation.score).to eq(3)
      expect(evaluation.feedback).to eq("Needs improvement")
      expect(evaluation.evaluator).to eq(evaluator)
    end
  end

  describe 'custom validation methods' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }
    let(:evaluator) { create(:user) }

    describe '#assignment_must_be_completed' do
      it 'passes when assignment is completed' do
        completed_assignment = create(:assignment, :completed, membership: membership, task: task, due_date: Date.yesterday)
        evaluation = build(:evaluation, assignment: completed_assignment, evaluator: evaluator)
        expect(evaluation).to be_valid
      end

      it 'fails when assignment is pending' do
        pending_assignment = create(:assignment, membership: membership, task: task, status: 'pending')
        evaluation = build(:evaluation, assignment: pending_assignment, evaluator: evaluator)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:assignment]).to include("は完了状態でないと評価できません")
      end

      it 'fails when assignment is in_progress' do
        in_progress_assignment = create(:assignment, membership: membership, task: task, status: 'in_progress')
        evaluation = build(:evaluation, assignment: in_progress_assignment, evaluator: evaluator)
        expect(evaluation).not_to be_valid
        expect(evaluation.errors[:assignment]).to include("は完了状態でないと評価できません")
      end

      it 'passes when assignment is nil (handled by belongs_to validation)' do
        evaluation = build(:evaluation, assignment: nil, evaluator: evaluator)
        evaluation.valid?
        # assignment_must_be_completed should not add errors when assignment is nil
        # The belongs_to validation will handle the nil case
        expect(evaluation.errors[:assignment]).not_to include("は完了状態でないと評価できません")
      end
    end
  end

  describe 'business logic scenarios' do
    let(:group) { create(:group) }
    let(:task) { create(:task, group: group) }
    let(:membership1) { create(:membership, group: group) }
    let(:membership2) { create(:membership, group: group) }
    let(:evaluator1) { create(:user) }
    let(:evaluator2) { create(:user) }

    describe 'evaluation workflow' do
      it 'allows multiple evaluators to evaluate same completed assignment' do
        assignment = create(:assignment, :completed, membership: membership1, task: task, due_date: Date.yesterday)
        
        evaluation1 = create(:evaluation, assignment: assignment, evaluator: evaluator1, score: 4, feedback: "Good work")
        evaluation2 = create(:evaluation, assignment: assignment, evaluator: evaluator2, score: 5, feedback: "Excellent!")
        
        expect(evaluation1).to be_valid
        expect(evaluation2).to be_valid
        expect(assignment.evaluations.count).to eq(2)
      end

      it 'prevents same evaluator from evaluating same assignment twice' do
        assignment = create(:assignment, :completed, membership: membership1, task: task, due_date: Date.yesterday)
        
        create(:evaluation, assignment: assignment, evaluator: evaluator1, score: 4)
        duplicate_evaluation = build(:evaluation, assignment: assignment, evaluator: evaluator1, score: 5)
        
        expect(duplicate_evaluation).not_to be_valid
        expect(duplicate_evaluation.errors[:assignment_id]).to include("は既に評価済みです")
      end

      it 'allows same evaluator to evaluate different assignments' do
        assignment1 = create(:assignment, :completed, membership: membership1, task: task, due_date: Date.yesterday)
        assignment2 = create(:assignment, :completed, membership: membership2, task: task, due_date: Date.yesterday)
        
        evaluation1 = create(:evaluation, assignment: assignment1, evaluator: evaluator1, score: 4)
        evaluation2 = create(:evaluation, assignment: assignment2, evaluator: evaluator1, score: 3)
        
        expect(evaluation1).to be_valid
        expect(evaluation2).to be_valid
      end
    end

    describe 'score ranges and feedback scenarios' do
      let(:assignment) { create(:assignment, :completed, membership: membership1, task: task, due_date: Date.yesterday) }

      it 'handles minimum score with detailed feedback' do
        evaluation = create(:evaluation, 
          assignment: assignment, 
          evaluator: evaluator1, 
          score: 1, 
          feedback: "作業が不完全で、期待される品質に達していませんでした。"
        )
        expect(evaluation).to be_valid
        expect(evaluation.score).to eq(1)
      end

      it 'handles maximum score with praise feedback' do
        evaluation = create(:evaluation, 
          assignment: assignment, 
          evaluator: evaluator1, 
          score: 5, 
          feedback: "期待を上回る素晴らしい仕事でした！"
        )
        expect(evaluation).to be_valid
        expect(evaluation.score).to eq(5)
      end

      it 'handles average score with constructive feedback' do
        evaluation = create(:evaluation, 
          assignment: assignment, 
          evaluator: evaluator1, 
          score: 3, 
          feedback: "良い仕事でしたが、いくつか改善点があります。"
        )
        expect(evaluation).to be_valid
        expect(evaluation.score).to eq(3)
      end

      it 'handles evaluation without feedback' do
        evaluation = create(:evaluation, 
          assignment: assignment, 
          evaluator: evaluator1, 
          score: 4, 
          feedback: nil
        )
        expect(evaluation).to be_valid
        expect(evaluation.feedback).to be_nil
      end
    end
  end

  describe 'database constraints' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }
    let(:assignment) { create(:assignment, :completed, membership: membership, task: task, due_date: Date.yesterday) }
    let(:evaluator) { create(:user) }

    it 'enforces unique constraint via model validation' do
      create(:evaluation, assignment: assignment, evaluator: evaluator)
      
      # Applicationレベルのバリデーションで重複が防止されることを確認
      duplicate_evaluation = build(:evaluation, assignment: assignment, evaluator: evaluator, score: 3)
      expect(duplicate_evaluation).not_to be_valid
      expect(duplicate_evaluation.errors[:assignment_id]).to include("は既に評価済みです")
    end
  end
end
