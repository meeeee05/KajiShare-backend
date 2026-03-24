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
    it { should validate_numericality_of(:point).is_greater_than_or_equal_to(1) }
    it { should validate_numericality_of(:point).is_less_than_or_equal_to(5) }

    # 異常系：同一グループ内で同名タスクは作成不可
    it 'does not allow duplicate name within the same group' do
      existing = create(:task)
      duplicate = build(:task, group: existing.group, name: existing.name)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:name]).to include('はこのグループ内ですでに登録されています')
    end

    # 正常系：別グループなら同名タスクを作成可能
    it 'allows same name in different groups' do
      existing = create(:task)
      other_group = create(:group)
      same_name_task = build(:task, group: other_group, name: existing.name)

      expect(same_name_task).to be_valid
    end

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
      expect(task.errors[:point]).to include('must be greater than or equal to 1')
    end

    # 異常系：pointが正の整数でない（０）
    it 'does not allow zero points' do
      task = build(:task, point: 0)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be greater than or equal to 1')
    end

    # 異常系：pointが上限を超えている
    it 'does not allow points greater than 5' do
      task = build(:task, point: 6)
      expect(task).not_to be_valid
      expect(task.errors[:point]).to include('must be less than or equal to 5')
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
