require 'rails_helper'

RSpec.describe Assignment, type: :model do
  describe 'associations' do
    it { should belong_to(:task) }
    it { should belong_to(:membership) }
    it { should have_many(:evaluations).dependent(:destroy) }
  end

  describe 'validations' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }

    describe 'presence validations' do
      it 'requires task_id' do
        assignment = build(:assignment, task: nil, membership: membership)
        expect(assignment).not_to be_valid
        expect(assignment.errors[:task]).to include("must exist")
      end

      it 'requires membership_id' do
        assignment = build(:assignment, task: task, membership: nil)
        expect(assignment).not_to be_valid
        expect(assignment.errors[:membership]).to include("must exist")
      end

      it 'requires status' do
        # statusがenumで定義されており、presence validationがあることを確認
        assignment = build(:assignment, task: task, membership: membership)
        expect(assignment.status).to be_present
        expect(['pending', 'in_progress', 'completed']).to include(assignment.status)
      end
    end

    describe 'uniqueness validation' do
      it 'prevents duplicate task assignment to same membership' do
        create(:assignment, task: task, membership: membership)
        duplicate_assignment = build(:assignment, task: task, membership: membership)
        
        expect(duplicate_assignment).not_to be_valid
        expect(duplicate_assignment.errors[:task_id]).to include("has already been taken")
      end

      it 'allows same task to be assigned to different memberships' do
        membership2 = create(:membership, group: task.group)
        create(:assignment, task: task, membership: membership)
        assignment2 = build(:assignment, task: task, membership: membership2)
        
        expect(assignment2).to be_valid
      end

      it 'allows different tasks to be assigned to same membership' do
        task2 = create(:task, group: membership.group)
        create(:assignment, task: task, membership: membership)
        assignment2 = build(:assignment, task: task2, membership: membership)
        
        expect(assignment2).to be_valid
      end
    end

    describe 'completed_date validation' do
      context 'when status is completed' do
        it 'requires completed_date to be present' do
          assignment = build(:assignment, task: task, membership: membership, status: 'completed', completed_date: nil)
          expect(assignment).not_to be_valid
          expect(assignment.errors[:completed_date]).to include("can't be blank")
        end

        it 'is valid with completed_date' do
          assignment = build(:assignment, 
            task: task, 
            membership: membership, 
            status: 'completed', 
            due_date: Date.yesterday,
            completed_date: Date.current
          )
          expect(assignment).to be_valid
        end
      end

      context 'when status is not completed' do
        it 'does not require completed_date for pending status' do
          assignment = build(:assignment, task: task, membership: membership, status: 'pending', completed_date: nil)
          expect(assignment).to be_valid
        end

        it 'does not require completed_date for in_progress status' do
          assignment = build(:assignment, task: task, membership: membership, status: 'in_progress', completed_date: nil)
          expect(assignment).to be_valid
        end
      end
    end

    describe 'completed_date_after_due_date validation' do
      it 'is valid when completed_date is after due_date' do
        assignment = build(:assignment, 
          task: task, 
          membership: membership,
          due_date: Date.yesterday,
          completed_date: Date.current,
          status: 'completed'
        )
        expect(assignment).to be_valid
      end

      it 'is valid when completed_date equals due_date' do
        assignment = build(:assignment, 
          task: task, 
          membership: membership,
          due_date: Date.current,
          completed_date: Date.current,
          status: 'completed'
        )
        expect(assignment).to be_valid
      end

      it 'is invalid when completed_date is before due_date' do
        assignment = build(:assignment, 
          task: task, 
          membership: membership,
          due_date: Date.current,
          completed_date: Date.yesterday,
          status: 'completed'
        )
        expect(assignment).not_to be_valid
        expect(assignment.errors[:completed_date]).to include("は期限日以降である必要があります")
      end

      it 'does not validate when completed_date is nil' do
        assignment = build(:assignment, 
          task: task, 
          membership: membership,
          due_date: Date.current,
          completed_date: nil,
          status: 'pending'
        )
        expect(assignment).to be_valid
      end

      it 'does not validate when due_date is nil' do
        assignment = build(:assignment, 
          task: task, 
          membership: membership,
          due_date: nil,
          completed_date: Date.current,
          status: 'completed'
        )
        expect(assignment).to be_valid
      end
    end
  end

  describe 'enums' do
    describe 'status enum' do
      let(:assignment) { create(:assignment) }

      it 'defines pending status' do
        assignment.update!(status: 'pending')
        expect(assignment.pending?).to be true
        expect(assignment.in_progress?).to be false
        expect(assignment.completed?).to be false
      end

      it 'defines in_progress status' do
        assignment.update!(status: 'in_progress')
        expect(assignment.in_progress?).to be true
        expect(assignment.pending?).to be false
        expect(assignment.completed?).to be false
      end

      it 'defines completed status' do
        assignment.update!(status: 'completed', due_date: Date.yesterday, completed_date: Date.current)
        expect(assignment.completed?).to be true
        expect(assignment.pending?).to be false
        expect(assignment.in_progress?).to be false
      end
    end
  end

  describe 'callbacks' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }

    describe 'sync_status_with_completed_date' do
      context 'when completed_date is present' do
        it 'automatically sets status to completed' do
          assignment = build(:assignment, 
            task: task, 
            membership: membership,
            due_date: Date.yesterday,
            completed_date: Date.current,
            status: 'pending'
          )
          assignment.save!
          expect(assignment.status).to eq('completed')
        end
      end

      context 'when completed_date is blank' do
        it 'sets status to pending if status is blank' do
          assignment = build(:assignment, 
            task: task, 
            membership: membership,
            completed_date: nil,
            status: nil
          )
          assignment.save!
          expect(assignment.status).to eq('pending')
        end

        it 'keeps existing status if status is not blank' do
          assignment = build(:assignment, 
            task: task, 
            membership: membership,
            completed_date: nil,
            status: 'in_progress'
          )
          assignment.save!
          expect(assignment.status).to eq('in_progress')
        end
      end
    end
  end

  describe 'factory' do
    it 'creates valid assignment' do
      assignment = create(:assignment)
      expect(assignment).to be_valid
      expect(assignment.pending?).to be true
      expect(assignment.due_date).to be_present
      expect(assignment.comment).to be_present
    end

    it 'creates valid completed assignment with trait' do
      assignment = create(:assignment, :completed, due_date: 2.days.ago)
      expect(assignment).to be_valid
      expect(assignment.completed?).to be true
      expect(assignment.completed_date).to be_present
    end

    it 'creates valid in_progress assignment with trait' do
      assignment = create(:assignment, :in_progress)
      expect(assignment).to be_valid
      expect(assignment.in_progress?).to be true
    end
  end

  describe 'dependent destroy behavior' do
    let(:assignment) { create(:assignment, :completed, due_date: Date.yesterday) }
    let(:evaluation) { create(:evaluation, assignment: assignment) }

    before do
      # データを作成してから削除テスト
      evaluation
    end

    it 'destroys associated evaluations when assignment is destroyed' do
      expect { assignment.destroy }.to change { Evaluation.count }.by(-1)
    end
  end

  describe 'instance methods' do
    let(:assignment) { create(:assignment) }

    describe 'status checking methods' do
      context 'when pending' do
        it 'returns true for pending?' do
          expect(assignment.pending?).to be true
        end

        it 'returns false for other status checks' do
          expect(assignment.in_progress?).to be false
          expect(assignment.completed?).to be false
        end
      end

      context 'when in_progress' do
        before { assignment.update!(status: 'in_progress') }

        it 'returns true for in_progress?' do
          expect(assignment.in_progress?).to be true
        end

        it 'returns false for other status checks' do
          expect(assignment.pending?).to be false
          expect(assignment.completed?).to be false
        end
      end

      context 'when completed' do
        before { assignment.update!(status: 'completed', due_date: Date.yesterday, completed_date: Date.current) }

        it 'returns true for completed?' do
          expect(assignment.completed?).to be true
        end

        it 'returns false for other status checks' do
          expect(assignment.pending?).to be false
          expect(assignment.in_progress?).to be false
        end
      end
    end
  end

  describe 'business logic scenarios' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }

    describe 'assignment lifecycle' do
      it 'can progress from pending to in_progress to completed' do
        # Create pending assignment
        assignment = create(:assignment, task: task, membership: membership, status: 'pending')
        expect(assignment.pending?).to be true

        # Move to in_progress
        assignment.update!(status: 'in_progress')
        expect(assignment.in_progress?).to be true

        # Complete the assignment
        assignment.update!(status: 'completed', due_date: Date.yesterday, completed_date: Date.current)
        expect(assignment.completed?).to be true
        expect(assignment.completed_date).to be_present
      end

      it 'can be completed directly from pending' do
        assignment = create(:assignment, task: task, membership: membership, status: 'pending')
        assignment.update!(status: 'completed', due_date: Date.yesterday, completed_date: Date.current)
        expect(assignment.completed?).to be true
      end
    end

    describe 'completion date logic' do
      it 'automatically becomes completed when completed_date is set' do
        assignment = create(:assignment, task: task, membership: membership, status: 'pending', due_date: Date.yesterday)
        assignment.update!(completed_date: Date.current)
        assignment.reload
        expect(assignment.completed?).to be true
      end

      it 'allows completion on the due date' do
        assignment = build(:assignment, 
          task: task, 
          membership: membership,
          due_date: Date.current,
          completed_date: Date.current
        )
        expect(assignment).to be_valid
        assignment.save!
        expect(assignment.completed?).to be true
      end
    end
  end
end
