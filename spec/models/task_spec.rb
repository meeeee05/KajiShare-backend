# spec/models/task_spec.rb
require 'rails_helper'

RSpec.describe Task, type: :model do
  describe 'validations' do
    subject { build(:task) }

    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_length_of(:description).is_at_most(50) }
    it { should validate_presence_of(:point) }
    it { should validate_numericality_of(:point).only_integer }
    it { should validate_numericality_of(:point).is_greater_than(0) }

    it 'allows blank description' do
      task = build(:task, description: '')
      expect(task).to be_valid
    end

    it 'allows nil description' do
      task = build(:task, description: nil)
      expect(task).to be_valid
    end

    it 'does not allow negative points' do
      task = build(:task, point: -1)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be greater than 0')
    end

    it 'does not allow zero points' do
      task = build(:task, point: 0)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be greater than 0')
    end

    it 'does not allow decimal points' do
      task = build(:task, point: 1.5)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be an integer')
    end
  end

  describe 'associations' do
    it { should belong_to(:group) }
    it { should have_many(:assignments).dependent(:destroy) }
  end

  describe 'factory' do
    it 'creates a valid task' do
      task = create(:task)
      expect(task).to be_valid
    end

    it 'creates task with proper associations' do
      group = create(:group)
      task = create(:task, group: group)
      expect(task.group).to eq(group)
    end
  end

  describe 'dependent destroy' do
    it 'destroys associated assignments when task is destroyed' do
      task = create(:task)
      assignment = create(:assignment, task: task)
      
      expect { task.destroy }.to change { Assignment.count }.by(-1)
    end
  end
end
