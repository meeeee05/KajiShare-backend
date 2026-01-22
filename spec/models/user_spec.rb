# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:groups).through(:memberships) }
    it { should have_many(:assignments).through(:memberships).dependent(:destroy) }
    it { should have_many(:evaluations).with_foreign_key(:evaluator_id).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:user) }

    describe 'google_sub validation' do
      it { should validate_presence_of(:google_sub) }
      it { should validate_uniqueness_of(:google_sub) }
      
      it 'is valid with unique google_sub' do
        user = build(:user, google_sub: 'unique_google_sub_123')
        expect(user).to be_valid
      end

      it 'is invalid with duplicate google_sub' do
        create(:user, google_sub: 'duplicate_sub')
        user = build(:user, google_sub: 'duplicate_sub')
        expect(user).not_to be_valid
        expect(user.errors[:google_sub]).to include("has already been taken")
      end
    end

    describe 'email validation' do
      it { should validate_presence_of(:email) }
      it { should validate_uniqueness_of(:email) }

      it 'accepts valid email formats' do
        valid_emails = [
          'user@example.com',
          'test.email@domain.co.jp',
          'user+tag@example.org',
          'user123@test-domain.com'
        ]
        
        valid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).to be_valid, "Expected #{email} to be valid"
        end
      end

      it 'rejects invalid email formats' do
        invalid_emails = [
          'invalid-email',
          '@example.com',
          'user@',
          'user@.com',
          ''
        ]
        
        invalid_emails.each do |email|
          user = build(:user, email: email)
          expect(user).not_to be_valid, "Expected #{email} to be invalid"
          expect(user.errors[:email]).to include('is invalid')
        end
      end

      it 'is invalid with duplicate email' do
        create(:user, email: 'duplicate@example.com')
        user = build(:user, email: 'duplicate@example.com')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("has already been taken")
      end

      it 'handles case sensitivity properly' do
        create(:user, email: 'User@Example.Com')
        user = build(:user, email: 'user@example.com')
        # Rails defaults to case-sensitive uniqueness
        expect(user).to be_valid
      end
    end

    describe 'name validation' do
      it { should validate_presence_of(:name) }
      it { should validate_length_of(:name).is_at_most(50) }

      it 'accepts names up to 50 characters' do
        name = 'a' * 50
        user = build(:user, name: name)
        expect(user).to be_valid
      end

      it 'rejects names longer than 50 characters' do
        name = 'a' * 51
        user = build(:user, name: name)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("is too long (maximum is 50 characters)")
      end

      it 'accepts Japanese names' do
        user = build(:user, name: '田中太郎')
        expect(user).to be_valid
      end

      it 'accepts names with spaces and special characters' do
        names = [
          'John Doe',
          "O'Connor",
          'Jean-Claude Van Damme',
          'José María'
        ]
        
        names.each do |name|
          user = build(:user, name: name)
          expect(user).to be_valid, "Expected '#{name}' to be valid"
        end
      end
    end

    describe 'account_type validation' do
      it { should validate_presence_of(:account_type) }
      it { should validate_inclusion_of(:account_type).in_array(%w[user admin]) }

      it 'accepts "user" account type' do
        user = build(:user, account_type: 'user')
        expect(user).to be_valid
      end

      it 'accepts "admin" account type' do
        user = build(:user, account_type: 'admin')
        expect(user).to be_valid
      end

      it 'rejects invalid account types' do
        invalid_types = ['superuser', 'moderator', '', nil, 'User', 'ADMIN']
        
        invalid_types.each do |type|
          user = build(:user, account_type: type)
          expect(user).not_to be_valid, "Expected account_type '#{type}' to be invalid"
          if type.present?
            expect(user.errors[:account_type]).to include("is not included in the list")
          else
            expect(user.errors[:account_type]).to include("can't be blank")
          end
        end
      end
    end

    describe 'picture validation' do
      it 'allows nil picture' do
        user = build(:user, picture: nil)
        expect(user).to be_valid
      end

      it 'allows valid picture URL' do
        user = build(:user, picture: 'https://example.com/avatar.jpg')
        expect(user).to be_valid
      end

      it 'allows empty picture string' do
        user = build(:user, picture: '')
        expect(user).to be_valid
      end
    end
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = create(:user)
      expect(user).to be_valid
      expect(user.account_type).to eq('user')
      expect(user.google_sub).to be_present
      expect(user.email).to be_present
      expect(user.name).to be_present
    end

    it 'creates an admin user with admin trait' do
      user = create(:user, :admin)
      expect(user).to be_valid
      expect(user.account_type).to eq('admin')
    end

    it 'creates users with sequential attributes' do
      user1 = create(:user)
      user2 = create(:user)
      
      expect(user1.google_sub).not_to eq(user2.google_sub)
      expect(user1.email).not_to eq(user2.email)
      expect(user1.name).not_to eq(user2.name)
    end
  end

  describe 'dependent destroy behavior' do
    let(:user) { create(:user) }
    let(:group) { create(:group) }
    let(:membership) { create(:membership, user: user, group: group) }
    let(:task1) { create(:task, group: group) }
    let(:task2) { create(:task, group: group) }
    let(:assignment) { create(:assignment, membership: membership, task: task1) }
    let(:completed_assignment) { create(:assignment, :completed, membership: membership, task: task2, due_date: Date.yesterday) }

    before do
      # データを作成
      assignment
      completed_assignment
    end

    it 'destroys associated memberships when user is destroyed' do
      membership # Create the membership
      expect { user.destroy }.to change { Membership.count }.by(-1)
    end

    it 'destroys associated assignments when user is destroyed' do
      expect { user.destroy }.to change { Assignment.count }.by(-2)
    end

    it 'destroys associated evaluations as evaluator when user is destroyed' do
      evaluation = create(:evaluation, assignment: completed_assignment, evaluator: user)
      expect { user.destroy }.to change { Evaluation.count }.by(-1)
    end
  end

  describe 'business logic scenarios' do
    describe 'user roles and permissions' do
      it 'distinguishes between user and admin accounts' do
        regular_user = create(:user, account_type: 'user')
        admin_user = create(:user, account_type: 'admin')
        
        expect(regular_user.account_type).to eq('user')
        expect(admin_user.account_type).to eq('admin')
      end
    end

    describe 'group membership scenarios' do
      let(:user) { create(:user) }
      let(:group1) { create(:group) }
      let(:group2) { create(:group) }

      it 'can belong to multiple groups' do
        membership1 = create(:membership, user: user, group: group1)
        membership2 = create(:membership, user: user, group: group2)
        
        expect(user.groups).to include(group1, group2)
        expect(user.memberships).to include(membership1, membership2)
      end

      it 'can have different roles in different groups' do
        admin_membership = create(:membership, :admin, user: user, group: group1)
        member_membership = create(:membership, user: user, group: group2, role: 'member')
        
        expect(admin_membership.admin?).to be true
        expect(member_membership.member?).to be true
        expect(user.memberships.count).to eq(2)
      end
    end

    describe 'assignment and evaluation scenarios' do
      let(:user) { create(:user) }
      let(:evaluator) { create(:user) }
      let(:group) { create(:group) }
      let(:membership) { create(:membership, user: user, group: group) }
      let(:task) { create(:task, group: group) }

      it 'can have assignments through memberships' do
        assignment1 = create(:assignment, membership: membership, task: task)
        assignment2 = create(:assignment, membership: membership, task: create(:task, group: group))
        
        expect(user.assignments).to include(assignment1, assignment2)
      end

      it 'can evaluate others assignments' do
        other_user = create(:user)
        other_membership = create(:membership, user: other_user, group: group)
        assignment = create(:assignment, :completed, membership: other_membership, task: task, due_date: Date.yesterday)
        
        evaluation = create(:evaluation, assignment: assignment, evaluator: user)
        
        expect(user.evaluations).to include(evaluation)
        expect(evaluation.evaluator).to eq(user)
      end
    end
  end

  describe 'edge cases and data integrity' do
    it 'handles long but valid names' do
      long_name = 'a' * 50  # Exactly 50 characters
      user = create(:user, name: long_name)
      expect(user).to be_valid
      expect(user.name.length).to eq(50)
    end

    it 'handles special characters in google_sub' do
      user = create(:user, google_sub: 'user-123_456.789')
      expect(user).to be_valid
    end

    it 'ensures data consistency after creation' do
      user = create(:user)
      
      # Verify all required fields are present
      expect(user.google_sub).to be_present
      expect(user.email).to be_present
      expect(user.name).to be_present
      expect(user.account_type).to be_present
      
      # Verify timestamps
      expect(user.created_at).to be_present
      expect(user.updated_at).to be_present
    end
  end
end
