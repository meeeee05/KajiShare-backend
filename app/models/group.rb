class Group < ApplicationRecord
  ASSIGN_MODE_VALUES = %w[manual random balanced].freeze

  #model関連付け 
  belongs_to :creator, class_name: "User", foreign_key: :created_by_id, optional: true
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships
  has_many :tasks, dependent: :destroy
  has_many :assignments, through: :tasks, dependent: :destroy
  has_many :evaluations, through: :assignments, dependent: :destroy

  before_validation :assign_share_key, on: :create
  before_validation :normalize_assign_mode
  after_create :ensure_creator_membership

  # バリデーション
  validates :name,
            presence: true,
            length: { maximum: 100 }

  validates :share_key,
            presence: true,
            uniqueness: true

  validates :assign_mode,
            inclusion: { in: ASSIGN_MODE_VALUES },
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

  # フロントの表記ゆれを既存保存値へ正規化
  def normalize_assign_mode
    return if assign_mode.blank?

    self.assign_mode = ASSIGN_MODE_ALIASES.fetch(assign_mode, assign_mode)
  end

  # 作成者が設定されている場合、作成者をAdminとしてグループに自動参加させる
  def ensure_creator_membership
    return unless self.class.column_names.include?("created_by_id")
    return if creator.blank?

    memberships.find_or_create_by!(user: creator) do |membership|
      membership.role = "admin"
      membership.active = true
    end
  end
end