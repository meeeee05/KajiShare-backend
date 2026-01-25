# spec/models/task_spec.rb
require 'rails_helper'

# Taskモデル関連付けテスト
RSpec.describe Task, type: :model do
  describe 'validations' do
    subject { build(:task) }

    # shoulda-matchersで宣言的に網羅（入力値検証）
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(50) }
    it { should validate_length_of(:description).is_at_most(50) }
    it { should validate_presence_of(:point) }
    it { should validate_numericality_of(:point).only_integer }
    it { should validate_numericality_of(:point).is_greater_than(0) }

    # 正常系：descriptionが空文字でも登録可能
    it 'allows blank description' do
      task = build(:task, description: '')
      expect(task).to be_valid
    end

    # 正常系：descriptionがnilでも登録可能
    it 'allows nil description' do
      task = build(:task, description: nil)
      expect(task).to be_valid
    end

    # 異常系：pointが正の整数でない（マイナス値）
    it 'does not allow negative points' do
      task = build(:task, point: -1)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be greater than 0')
    end

    # 異常系：pointが正の整数でない（０）
    it 'does not allow zero points' do
      task = build(:task, point: 0)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be greater than 0')
    end

    # 異常系：pointが正の整数でない（少数値）
    it 'does not allow decimal points' do
      task = build(:task, point: 1.5)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be an integer')
    end
  end

  # Taskモデル関連付けテスト
  describe 'associations' do
    it { should belong_to(:group) }
    it { should have_many(:assignments).dependent(:destroy) }
  end

  # 正常系：taskを正しく作成できる
  describe 'factory' do
    it 'creates a valid task' do
      task = create(:task)
      expect(task).to be_valid
    end

    # 正常系：Taskが正しくGroupに紐付く
    it 'creates task with proper associations' do
      group = create(:group)
      task = create(:task, group: group)
      expect(task.group).to eq(group)
    end
  end

 # 正常系：taskに紐づく先も一緒に削除される
  describe 'dependent destroy' do
    it 'destroys associated assignments when task is destroyed' do
      task = create(:task)
      assignment = create(:assignment, task: task)
      expect { task.destroy }.to change(Assignment, :count).by(-1)
    end
  end
end
