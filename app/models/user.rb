class User < ApplicationRecord
  #model関連付け
  has_many :memberships, dependent: :destroy
  has_many :groups, through: :memberships
  has_many :assignments, through: :memberships, dependent: :destroy
  has_many :evaluations, foreign_key: :evaluator_id, dependent: :destroy

  #バリデーション（フォーマットチェック）
  validates :google_sub,
            presence: true,
            uniqueness: true

  validates :email,
            presence: true,
            uniqueness: true,
            format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :name,
            presence: true,
            length: { maximum: 50 }

  validates :account_type,
            presence: true,

            # "user" または "admin" 以外の値を拒否
            inclusion: { in: %w[user admin] }

end
