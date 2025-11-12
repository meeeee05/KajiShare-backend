class AddActiveToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :active, :boolean
  end
end
