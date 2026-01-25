# spec/models/group_spec.rb
require 'rails_helper'

# Groupモデル関連付けテスト
RSpec.describe Group, type: :model do
  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:users).through(:memberships) }
    it { should have_many(:tasks).dependent(:destroy) }
    it { should have_many(:assignments).through(:tasks) }
    it { should have_many(:evaluations).through(:assignments) }
  end

  # shoulda-matchersで宣言的に網羅（入力値検証）
  describe 'validations' do
    subject { build(:group) }
    before { create(:group) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_presence_of(:share_key) }
    it { should validate_uniqueness_of(:share_key) }
    it { should validate_presence_of(:assign_mode) }
    it { should validate_inclusion_of(:assign_mode).in_array(%w[equal ratio manual]) }
    it { should validate_presence_of(:balance_type) }
    it { should validate_inclusion_of(:balance_type).in_array(%w[point time]) }
  end

  # 異常系：group名が空の場合は保存できない
  describe 'invalid cases' do
    it 'is invalid with empty name' do
      group = build(:group, name: '')
      expect(group).not_to be_valid
    end

    # 異常系：group名が100字異常の場合は保存できない
    it 'is invalid with too long name' do
      group = build(:group, name: 'a' * 101)
      expect(group).not_to be_valid
    end

    # 異常系：assign_modeが定義外の値の場合は保存できない
    it 'is invalid with invalid assign_mode' do
      group = build(:group, assign_mode: 'invalid')
      expect(group).not_to be_valid
    end

    # 異常系：balance_typeが定義外の値の場合は保存できない
    it 'is invalid with invalid balance_type' do
      group = build(:group, balance_type: 'invalid')
      expect(group).not_to be_valid
    end
  end

  # 正常系：groupを正しく作成できる
  describe 'factory' do
    it 'creates a valid group' do
      expect(create(:group)).to be_valid
    end
  end
end