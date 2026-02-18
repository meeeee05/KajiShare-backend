class Group < ApplicationRecord
  #model関連付け 
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :tasks, dependent: :destroy
  has_many :assignments, through: :tasks, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  before_validation :assign_share_key, on: :create

  # バリデーション
  validates :name,
            presence: true,
            length: { maximum: 100 }

  validates :share_key,
            presence: true,
            uniqueness: true

  validates :assign_mode,
            presence: true,
            inclusion: { in: %w[equal ratio manual] }

  validates :balance_type,
            presence: true,
            inclusion: { in: %w[point time] }

  # active は boolean 型なので inclusion バリデーションは不要

  private

  # 6文字のランダムな大小アルファベットで share_key を自動採番
  def assign_share_key
    return if share_key.present?

    characters = [('A'..'Z'), ('a'..'z')].map(&:to_a).flatten
    begin
      self.share_key = Array.new(6) { characters.sample }.join
    end while self.class.exists?(share_key: share_key)
  end
end