class MigrateEveryNDaysToBiweeklyOnRecurringTasks < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE recurring_tasks
      SET schedule_type = 'biweekly', interval_days = NULL
      WHERE schedule_type = 'every_n_days';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE recurring_tasks
      SET schedule_type = 'every_n_days', interval_days = 14
      WHERE schedule_type = 'biweekly' AND interval_days IS NULL;
    SQL
  end
end
