class AddRegistrationAttestationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :registration_accepted_at, :datetime
    add_column :users, :registration_policy_version, :string
  end
end
