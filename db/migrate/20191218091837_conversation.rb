class Conversation < ActiveRecord::Migration[5.2]
  def change
    create_table :conversations do |t|
      t.references :user1, foreign_key: { to_table: 'users' }
      t.references :user2, foreign_key: { to_table: 'users' }
      t.timestamps
    end
  end
end
