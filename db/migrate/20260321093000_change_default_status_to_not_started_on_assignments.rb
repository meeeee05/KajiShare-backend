class ChangeDefaultStatusToNotStartedOnAssignments < ActiveRecord::Migration[8.0]
  def up
    change_column_default :assignments, :status, from: "pending", to: "着手前"

    execute <<~SQL
      UPDATE assignments
      SET status = '着手前'
      WHERE status = 'pending' OR status IS NULL
    SQL
  end

  def down
    execute <<~SQL
      UPDATE assignments
      SET status = 'pending'
      WHERE status = '着手前' OR status IS NULL
    SQL

    change_column_default :assignments, :status, from: "着手前", to: "pending"
  end
end
