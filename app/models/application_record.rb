# == Schema Information
#全モデルを正常に動作させるための基底クラス
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end
