# frozen_string_literal: true

class CreateChatReadStates < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_read_states do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :ride_post, null: false, foreign_key: { on_delete: :cascade }
      t.integer :last_read_message_id, default: 0, null: false

      t.timestamps
    end

    add_index :chat_read_states, [ :user_id, :ride_post_id ], unique: true
    add_check_constraint :chat_read_states, "last_read_message_id >= 0",
                         name: "check_chat_read_states_last_read_message_id_non_negative"
  end
end
