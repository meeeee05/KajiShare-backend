# spec/models/user_spec.rb
require 'rails_helper'

# Userモデル関連付けテスト
RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:groups).through(:memberships) }
    it { should have_many(:assignments).through(:memberships).dependent(:destroy) }
    it { should have_many(:evaluations).with_foreign_key(:evaluator_id).dependent(:destroy) }
  end

  # バリデーションテスト
  describe 'validations' do
    subject { build(:user) }

    # shoulda-matchersで宣言的に網羅（入力値検証）
    it { should validate_presence_of(:google_sub) }
    it { should validate_uniqueness_of(:google_sub) }
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_presence_of(:account_type) }
    it { should validate_inclusion_of(:account_type).in_array(%w[user admin]) }

    # 異常系：google_subの重複禁止
    it 'is invalid with duplicate google_sub' do
      create(:user, google_sub: 'dup')
      user = build(:user, google_sub: 'dup')
      expect(user).not_to be_valid
      expect(user.errors[:google_sub]).to include('has already been taken')
    end

    # 正常系：正しい形式のemailを許可
    it 'accepts valid email format' do
      user = build(:user, email: 'user@example.com')
      expect(user).to be_valid
    end

    # 異常系：emailの重複禁止
    it 'is invalid with duplicate email' do
      create(:user, email: 'dup@example.com')
      user = build(:user, email: 'dup@example.com')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('has already been taken')
    end

    # 異常系：emailの不正な形式
    it 'rejects invalid email format' do
      user = build(:user, email: 'invalid-email')
      expect(user).not_to be_valid
      expect(user.errors[:email]).to include('is invalid')
    end

    # 正常系：正しい形式のnameを許可
    it 'accepts name with 50 chars' do
      user = build(:user, name: 'a' * 50)
      expect(user).to be_valid
    end

    # 異常系：nameの長さ制限
    it 'rejects name longer than 50 chars' do
      user = build(:user, name: 'a' * 51)
      expect(user).not_to be_valid
      expect(user.errors[:name]).to include('is too long (maximum is 50 characters)')
    end

    # 正常系：正しい形式のaccount_typeを許可
    it 'accepts account_type user/admin' do
      expect(build(:user, account_type: 'user')).to be_valid
      expect(build(:user, account_type: 'admin')).to be_valid
    end

    # 異常系：不正なaccount_type
    it 'rejects invalid account_type' do
      user = build(:user, account_type: 'superuser')
      expect(user).not_to be_valid
      expect(user.errors[:account_type]).to include('is not included in the list')
    end
  end

  # 正常系：Userを正しく作成できる
  describe 'factory' do
    it 'creates a valid user' do
      expect(create(:user)).to be_valid
    end
    it 'creates an admin user' do
      expect(create(:user, :admin).account_type).to eq('admin')
    end
  end

 # 正常系：Userに紐づく先も一緒に削除される
  describe 'dependent destroy' do
    it 'destroys memberships, assignments, and evaluations' do
      user = create(:user)
      group = create(:group)
      membership = create(:membership, user: user, group: group)
      task = create(:task, group: group)
      assignment = create(:assignment, :completed, membership: membership, task: task, due_date: Date.yesterday)
      evaluation = create(:evaluation, assignment: assignment, evaluator: user)
      expect {
        user.destroy
      }.to change(Membership, :count).by(-1)
       .and change(Assignment, :count).by(-1)
       .and change(Evaluation, :count).by(-1)
    end
  end
end
