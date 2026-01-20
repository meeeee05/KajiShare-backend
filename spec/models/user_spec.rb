# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:google_sub) }
    it { should validate_uniqueness_of(:google_sub) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_presence_of(:account_type) }
    it { should validate_inclusion_of(:account_type).in_array(%w[user admin]) }

    it 'validates email format' do
      user = build(:user, email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end
  end

  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:groups).through(:memberships) }
    it { should have_many(:assignments).through(:memberships).dependent(:destroy) }
    it { should have_many(:evaluations).with_foreign_key(:evaluator_id).dependent(:destroy) }
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = create(:user)
      expect(user).to be_valid
    end

    it 'creates an admin user with admin trait' do
      user = create(:user, :admin)
      expect(user.account_type).to eq('admin')
    end
  end
end
