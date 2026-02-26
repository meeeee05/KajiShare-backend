class Group < ApplicationRecord
  #model関連付け 
  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :tasks, dependent: :destroy
  has_many :assignments, through: :tasks, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  before_validation :assign_share_key, on: :create
  after_create :ensure_creator_membership

  # バリデーション
  validates :name,
            presence: true,
            length: { maximum: 100 }

  validates :share_key,
            presence: true,
            uniqueness: true

  validates :assign_mode,
            inclusion: { in: %w[equal ratio manual] },
            allow_nil: true

  validates :balance_type,
            inclusion: { in: %w[point time] },
            allow_nil: true

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

  # 作成者が設定されている場合、作成者をAdminとしてグループに自動参加させる
  def ensure_creator_membership
    return if creator.blank?

    memberships.find_or_create_by!(user: creator) do |membership|
      membership.role = "admin"
      membership.active = true
    end
  end
end