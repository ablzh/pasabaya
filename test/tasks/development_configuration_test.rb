require "test_helper"
require "open3"
require "json"

class DevelopmentConfigurationTest < ActiveSupport::TestCase
  test "development boots and writes email without private credentials" do
    Dir.mktmpdir("pasabaya-local-mail-") do |directory|
      script = <<~RUBY
        require "./config/application"
        Rails.application.config.credentials.content_path = ARGV.fetch(0) + "/missing.yml.enc"
        Rails.application.config.credentials.key_path = ARGV.fetch(0) + "/missing.key"
        Rails.application.initialize!
        puts JSON.generate(delivery_method: ActionMailer::Base.delivery_method,
          mail_directory: ActionMailer::Base.file_settings.fetch(:location).to_s)
        abort "Development email must use local file delivery" unless ActionMailer::Base.delivery_method == :file
        ActionMailer::Base.file_settings = { location: ARGV.fetch(0) }
        class LocalVerificationMailer < ActionMailer::Base
          def confirmation
            mail(from: "local@example.test", to: "reader@example.test",
              subject: "Local delivery", body: "A local confirmation link")
          end
        end
        LocalVerificationMailer.confirmation.deliver_now
      RUBY

      output, error, status = Open3.capture3(
        { "RAILS_ENV" => "development", "RAILS_MASTER_KEY" => nil, "USE_MAILTRAP_SANDBOX" => nil },
        RbConfig.ruby, "-e", script, directory, chdir: Rails.root
      )

      assert status.success?, error
      configuration = JSON.parse(output.lines.find { |line| line.start_with?("{") })
      assert_equal "file", configuration.fetch("delivery_method")
      assert_equal Rails.root.join("tmp/mails").to_s, configuration.fetch("mail_directory")
      assert_includes File.read(File.join(directory, "reader@example.test")), "A local confirmation link"
    end
  end
end
