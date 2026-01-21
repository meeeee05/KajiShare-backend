# spec/models/group_spec.rb
require 'rails_helper'

RSpec.describe Group, type: :model do
  describe 'validations' do
    subject { build(:group) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_presence_of(:share_key) }
    it { should validate_uniqueness_of(:share_key) }
    it { should validate_presence_of(:assign_mode) }
    it { should validate_inclusion_of(:assign_mode).in_array(%w[equal ratio manual]) }
    it { should validate_presence_of(:balance_type) }
    it { should validate_inclusion_of(:balance_type).in_array(%w[point time]) }
    # active は boolean 型なので inclusion テストは不要
  end

  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:users).through(:memberships) }
    it { should have_many(:tasks).dependent(:destroy) }
    it { should have_many(:assignments).through(:tasks).dependent(:destroy) }
    it { should have_many(:evaluations).through(:assignments).dependent(:destroy) }
  end

  describe 'factory' do
    it 'creates a valid group' do
      group = create(:group)
      expect(group).to be_valid
    end
  end

  describe 'uniqueness validations' do
    it 'does not allow duplicate share_key' do
      create(:group, share_key: 'unique_key')
      duplicate_group = build(:group, share_key: 'unique_key')
      
      expect(duplicate_group).not_to be_valid
      expect(duplicate_group.errors[:share_key]).to include('has already been taken')
    end
  end
end
