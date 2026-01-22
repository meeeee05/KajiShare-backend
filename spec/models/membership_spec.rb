require 'rails_helper'

RSpec.describe Membership, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:group) }
    it { should have_many(:assignments).dependent(:destroy) }
    it { should have_many(:evaluations).through(:assignments).dependent(:destroy) }
  end

  describe 'validations' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }

    describe 'role validation' do
      it 'is valid with member role' do
        membership = build(:membership, user: user, group: group, role: 'member')
        expect(membership).to be_valid
      end

      it 'is valid with admin role' do
        membership = build(:membership, user: user, group: group, role: 'admin')
        expect(membership).to be_valid
      end

      it 'requires role to be present' do
        membership = build(:membership, user: user, group: group, role: nil)
        expect(membership).not_to be_valid
        expect(membership.errors[:role]).to include("can't be blank")
      end
    end

    describe 'uniqueness validation' do
      it 'prevents duplicate membership for same user and group' do
        create(:membership, user: user, group: group)
        duplicate_membership = build(:membership, user: user, group: group)
        
        expect(duplicate_membership).not_to be_valid
        expect(duplicate_membership.errors[:user_id]).to include("はすでにこのグループに参加しています")
      end

      it 'allows same user to join different groups' do
        group2 = create(:group)
        create(:membership, user: user, group: group)
        membership2 = build(:membership, user: user, group: group2)
        
        expect(membership2).to be_valid
      end

      it 'allows different users to join same group' do
        user2 = create(:user)
        create(:membership, user: user, group: group)
        membership2 = build(:membership, user: user2, group: group)
        
        expect(membership2).to be_valid
      end
    end

    describe 'workload_ratio validation' do
      it 'is valid with nil workload_ratio' do
        membership = build(:membership, user: user, group: group, workload_ratio: nil)
        expect(membership).to be_valid
      end

      it 'is valid with workload_ratio of 1.0' do
        membership = build(:membership, user: user, group: group, workload_ratio: 1.0)
        expect(membership).to be_valid
      end

      it 'is valid with workload_ratio of 100' do
        membership = build(:membership, user: user, group: group, workload_ratio: 100)
        expect(membership).to be_valid
      end

      it 'is valid with decimal workload_ratio (one decimal place)' do
        membership = build(:membership, user: user, group: group, workload_ratio: 50.5)
        expect(membership).to be_valid
      end

      it 'is invalid with workload_ratio of 0' do
        membership = build(:membership, user: user, group: group, workload_ratio: 0)
        expect(membership).not_to be_valid
        expect(membership.errors[:workload_ratio]).to include("must be greater than 0")
      end

      it 'is invalid with negative workload_ratio' do
        membership = build(:membership, user: user, group: group, workload_ratio: -1)
        expect(membership).not_to be_valid
        expect(membership.errors[:workload_ratio]).to include("must be greater than 0")
      end

      it 'is invalid with workload_ratio greater than 100' do
        membership = build(:membership, user: user, group: group, workload_ratio: 101)
        expect(membership).not_to be_valid
        expect(membership.errors[:workload_ratio]).to include("must be less than or equal to 100")
      end

      it 'is invalid with more than one decimal place' do
        membership = build(:membership, user: user, group: group, workload_ratio: 50.55)
        expect(membership).not_to be_valid
        expect(membership.errors[:workload_ratio]).to include("は小数第一位までの値を入力してください")
      end
    end
  end

  describe 'enums' do
    describe 'role enum' do
      it 'defines member role' do
        membership = create(:membership, role: 'member')
        expect(membership.member?).to be true
        expect(membership.admin?).to be false
      end

      it 'defines admin role' do
        membership = create(:membership, role: 'admin')
        expect(membership.admin?).to be true
        expect(membership.member?).to be false
      end
    end
  end

  describe 'factory' do
    it 'creates valid membership' do
      membership = create(:membership)
      expect(membership).to be_valid
      expect(membership.member?).to be true
      expect(membership.active).to be true
      expect(membership.workload_ratio).to eq(1.0)
    end

    it 'creates valid admin membership with trait' do
      membership = create(:membership, :admin)
      expect(membership).to be_valid
      expect(membership.admin?).to be true
    end

    it 'creates valid inactive membership with trait' do
      membership = create(:membership, :inactive)
      expect(membership).to be_valid
      expect(membership.active).to be false
    end
  end

  describe 'instance methods' do
    let(:membership) { create(:membership) }

    describe 'role checking methods' do
      context 'when member' do
        it 'returns true for member?' do
          expect(membership.member?).to be true
        end

        it 'returns false for admin?' do
          expect(membership.admin?).to be false
        end
      end

      context 'when admin' do
        let(:admin_membership) { create(:membership, :admin) }

        it 'returns true for admin?' do
          expect(admin_membership.admin?).to be true
        end

        it 'returns false for member?' do
          expect(admin_membership.member?).to be false
        end
      end
    end
  end

  describe 'dependent destroy behavior' do
    let(:membership) { create(:membership) }
    let(:task) { create(:task, group: membership.group) }
    let(:assignment) { create(:assignment, membership: membership, task: task, status: 'completed', due_date: Date.yesterday, completed_date: Date.current) }
    let(:evaluation) { create(:evaluation, assignment: assignment) }

    before do
      # データを作成してから削除テスト
      assignment
      evaluation
    end

    it 'destroys associated assignments when membership is destroyed' do
      expect { membership.destroy }.to change { Assignment.count }.by(-1)
    end

    it 'destroys associated evaluations when membership is destroyed' do
      expect { membership.destroy }.to change { Evaluation.count }.by(-1)
    end
  end

  describe 'custom validation methods' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }

    describe '#workload_ratio_precision' do
      it 'allows nil workload_ratio' do
        membership = build(:membership, user: user, group: group, workload_ratio: nil)
        expect(membership).to be_valid
      end

      it 'allows one decimal place' do
        membership = build(:membership, user: user, group: group, workload_ratio: 25.5)
        expect(membership).to be_valid
      end

      it 'allows integer values' do
        membership = build(:membership, user: user, group: group, workload_ratio: 75)
        expect(membership).to be_valid
      end

      it 'rejects more than one decimal place' do
        membership = build(:membership, user: user, group: group, workload_ratio: 25.55)
        expect(membership).not_to be_valid
        expect(membership.errors[:workload_ratio]).to include("は小数第一位までの値を入力してください")
      end

      it 'rejects excessive precision' do
        membership = build(:membership, user: user, group: group, workload_ratio: 33.333)
        expect(membership).not_to be_valid
        expect(membership.errors[:workload_ratio]).to include("は小数第一位までの値を入力してください")
      end
    end
  end
end
