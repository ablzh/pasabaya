# frozen_string_literal: true

require "test_helper"

class Users::BackfillFacebookUrlsServiceTest < ActiveSupport::TestCase
  setup do
    @tmp_dir = Rails.root.join("tmp", "test_backfill_#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(@tmp_dir)

    # Prepare known test users with various URL states
    @valid_user = User.create!(
      email_address: "valid_fb@example.com",
      password: "password123",
      first_name: "Valid",
      last_name: "User",
      facebook_profile_url: "https://facebook.com/valid.user"
    )

    @whitespace_user = User.create!(
      email_address: "whitespace_fb@example.com",
      password: "password123",
      first_name: "Whitespace",
      last_name: "User"
    )
    ActiveRecord::Base.connection.execute("UPDATE users SET facebook_profile_url = '  https://facebook.com/whitespace.user  ' WHERE id = #{@whitespace_user.id}")

    @http_user = User.create!(
      email_address: "http_fb@example.com",
      password: "password123",
      first_name: "Http",
      last_name: "User"
    )
    ActiveRecord::Base.connection.execute("UPDATE users SET facebook_profile_url = 'http://www.facebook.com/http.user' WHERE id = #{@http_user.id}")

    @deceptive_user = User.create!(
      email_address: "deceptive_fb@example.com",
      password: "password123",
      first_name: "Deceptive",
      last_name: "User"
    )
    ActiveRecord::Base.connection.execute("UPDATE users SET facebook_profile_url = 'https://facebook.com.evil.test/phish' WHERE id = #{@deceptive_user.id}")

    @credentials_user = User.create!(
      email_address: "cred_fb@example.com",
      password: "password123",
      first_name: "Cred",
      last_name: "User"
    )
    ActiveRecord::Base.connection.execute("UPDATE users SET facebook_profile_url = 'http://admin:secret@facebook.com/user' WHERE id = #{@credentials_user.id}")

    @bad_port_user = User.create!(
      email_address: "port_fb@example.com",
      password: "password123",
      first_name: "Port",
      last_name: "User"
    )
    ActiveRecord::Base.connection.execute("UPDATE users SET facebook_profile_url = 'http://facebook.com:8080/user' WHERE id = #{@bad_port_user.id}")

    @empty_path_user = User.create!(
      email_address: "path_fb@example.com",
      password: "password123",
      first_name: "Path",
      last_name: "User"
    )
    ActiveRecord::Base.connection.execute("UPDATE users SET facebook_profile_url = 'https://facebook.com/' WHERE id = #{@empty_path_user.id}")

    @blank_user = User.create!(
      email_address: "blank_fb@example.com",
      password: "password123",
      first_name: "Blank",
      last_name: "User",
      facebook_profile_url: nil
    )
  end

  teardown do
    FileUtils.rm_rf(@tmp_dir)
  end

  test "dry run calculates counts without modifying database records" do
    result = Users::BackfillFacebookUrlsService.run(
      dry_run: true,
      backup_dir: @tmp_dir
    )

    assert result.dry_run
    assert result.counts[:repairable] >= 2 # whitespace and http
    assert result.counts[:unrepairable] >= 4 # deceptive, credentials, bad port, empty path
    assert_nil result.backup_path

    # Verify records were NOT changed in DB
    assert_equal "  https://facebook.com/whitespace.user  ", @whitespace_user.reload.facebook_profile_url
    assert_equal "http://www.facebook.com/http.user", @http_user.reload.facebook_profile_url
    assert_equal "https://facebook.com.evil.test/phish", @deceptive_user.reload.facebook_profile_url
  end

  test "execution applies cleanup, preserves valid links, saves backup, and is idempotent" do
    result = Users::BackfillFacebookUrlsService.run(
      dry_run: false,
      backup_dir: @tmp_dir
    )

    assert_not result.dry_run
    assert_not_nil result.backup_path
    assert File.exist?(result.backup_path)

    # 1. Valid link is preserved unchanged
    assert_equal "https://facebook.com/valid.user", @valid_user.reload.facebook_profile_url

    # 2. Whitespace is trimmed
    assert_equal "https://facebook.com/whitespace.user", @whitespace_user.reload.facebook_profile_url

    # 3. HTTP is upgraded to HTTPS
    assert_equal "https://www.facebook.com/http.user", @http_user.reload.facebook_profile_url

    # 4. Unrepairable values are cleared to nil
    assert_nil @deceptive_user.reload.facebook_profile_url
    assert_nil @credentials_user.reload.facebook_profile_url
    assert_nil @bad_port_user.reload.facebook_profile_url
    assert_nil @empty_path_user.reload.facebook_profile_url
    assert_nil @blank_user.reload.facebook_profile_url

    # 5. Backup contains original values and restore works
    assert_equal "http://www.facebook.com/http.user", result.backup[@http_user.id]
    Users::BackfillFacebookUrlsService.restore!(result.backup)
    assert_equal "http://www.facebook.com/http.user", @http_user.reload.facebook_profile_url

    # Re-apply cleanup for idempotence check
    Users::BackfillFacebookUrlsService.run(dry_run: false, backup_dir: @tmp_dir)

    # 6. Idempotence: second run makes zero changes
    rerun = Users::BackfillFacebookUrlsService.run(dry_run: false, backup_dir: @tmp_dir)
    assert_equal 0, rerun.counts[:repairable]
    assert_equal 0, rerun.counts[:unrepairable]
    assert_equal rerun.counts[:total], rerun.counts[:unchanged]
  end

  test "guards against running against production without force flag" do
    original_env = Rails.env
    begin
      Rails.env = "production"
      assert_raises(RuntimeError, "Do not run this cleanup against production.") do
        Users::BackfillFacebookUrlsService.run
      end
    ensure
      Rails.env = original_env
    end
  end
end
