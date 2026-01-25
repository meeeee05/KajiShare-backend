require 'rails_helper'

# Membershipモデル関連付け
RSpec.describe Membership, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:group) }
    it { should have_many(:assignments).dependent(:destroy) }
    it { should have_many(:evaluations).through(:assignments).dependent(:destroy) }
  end

    # shoulda-matchersで宣言的に網羅（入力値検証）
  describe 'validations' do
    subject { build(:membership) }
    it { should validate_presence_of(:role) }
    it { should validate_numericality_of(:workload_ratio).is_greater_than(0).is_less_than_or_equal_to(100) }
    it { should allow_value(nil).for(:workload_ratio) }

    # 異常系：userとgroupの組み合わせの重複禁止
    it 'is invalid with duplicate user and group' do
      user = create(:user)
      group = create(:group)
      create(:membership, user: user, group: group, workload_ratio: 100)
      membership = build(:membership, user: user, group: group, workload_ratio: 100)
      expect(membership).not_to be_valid
    end

    # 異常系：workload_ratioが範囲外
    [
      { value: 101, desc: 'greater than 100' },
      { value: -1, desc: 'less than 0' },
      { value: 50.55, desc: 'more than 1 decimal' }
    ].each do |params|
      it "is invalid with workload_ratio #{params[:desc]} (#{params[:value]})" do
        membership = build(:membership, workload_ratio: params[:value])
        expect(membership).not_to be_valid
      end
    end

    # 正常系：workload_ratio、roleの値の制限が範囲内
    it 'accepts only member/admin as role' do
      expect(build(:membership, role: 'member')).to be_valid
      expect(build(:membership, role: 'admin')).to be_valid
      expect { build(:membership, role: 'invalid') }.to raise_error(ArgumentError)
    end

    # 異常系：グループ内workload_ratio合計が100でない
    context 'when workload_ratio sum in group is not exactly 100' do
      it 'is invalid if sum is not 100' do
        group = create(:group)
        membership = build(:membership, group: group, workload_ratio: 40)
        expect(membership).not_to be_valid
        expect(membership.errors[:workload_ratio]).to include('グループ内のworkload_ratio合計が100である必要があります')
      end

      it 'is valid if sum is exactly 100' do
        group = create(:group)
        membership = build(:membership, group: group, workload_ratio: 100)
        expect(membership).to be_valid
      end
    end
  end

  # 正常系：バリデーションを通過するmembershipオブジェクトを作成できる
  describe 'factory' do
    it 'creates a valid membership' do
      expect(create(:membership, workload_ratio: 100)).to be_valid
    end
    it 'creates a valid admin membership' do
      expect(create(:membership, :admin, workload_ratio: 100)).to be_valid
    end
  end

 # 正常系：Membershipに紐づく先も一緒に削除される
  describe 'dependent destroy' do
    it 'destroys assignments and evaluations' do
      membership = create(:membership, workload_ratio: 100)
      task = create(:task, group: membership.group)
      assignment = create(:assignment, membership: membership, task: task, status: 'completed', due_date: Date.yesterday, completed_date: Date.current)
      evaluation = create(:evaluation, assignment: assignment)
      expect { membership.destroy }.to change(Assignment, :count).by(-1)
        .and change(Evaluation, :count).by(-1)
    end
  end
end
