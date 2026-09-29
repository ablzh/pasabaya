class CreateCommunitiesAndMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :communities do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :domain, null: false
      t.integer :hub_type, default: 0, null: false

      t.timestamps
    end

    add_index :communities, :slug, unique: true
    add_index :communities, :domain, unique: true

    create_table :community_memberships do |t|
      t.references :user, null: false, foreign_key: true, index: false
      t.references :community, null: false, foreign_key: true, index: true
      t.string :institutional_email, null: false
      t.datetime :verified_at
      t.datetime :expires_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :community_memberships, [ :user_id, :community_id ], unique: true
    add_index :community_memberships, :institutional_email, unique: true,
              where: "verified_at IS NOT NULL AND revoked_at IS NULL",
              name: "index_community_memberships_on_institutional_email_active"

    add_foreign_key :ride_posts, :communities, column: :community_id, on_delete: :nullify
    add_check_constraint :ride_posts, "visibility != 1 OR community_id IS NOT NULL",
                         name: "check_ride_posts_hub_only_requires_community"
  end
end
