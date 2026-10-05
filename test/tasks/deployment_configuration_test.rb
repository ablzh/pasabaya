require "test_helper"
require "erb"
require "yaml"
require "open3"

class DeploymentConfigurationTest < ActiveSupport::TestCase
  test "one external host configures the web server and every accessory" do
    original_host = ENV["DEPLOY_HOST"]
    ENV["DEPLOY_HOST"] = "deploy.example.test"
    config = YAML.safe_load(ERB.new(Rails.root.join("config/deploy.yml").read).result)

    assert_equal [ "deploy.example.test" ], config.fetch("servers").fetch("web").fetch("hosts")
    assert config.fetch("accessories").values.all? { |accessory| accessory.fetch("host") == "deploy.example.test" }

    ENV.delete("DEPLOY_HOST")
    assert_raises(KeyError) { ERB.new(Rails.root.join("config/deploy.yml").read).result }
  ensure
    ENV["DEPLOY_HOST"] = original_host
  end

  test "Kamal uses an environment master key before falling back to a local key file" do
    Dir.mktmpdir("pasabaya-secret-adapter-") do |directory|
      key_mapping = Rails.root.join(".kamal/secrets").read.lines.find { |line| line.start_with?("RAILS_MASTER_KEY=") }
      File.write(File.join(directory, "secrets"), key_mapping)
      script = 'require "bundler/setup"; require "kamal"; print Kamal::Secrets.new(secrets_path: "secrets")["RAILS_MASTER_KEY"]'

      output, error, status = Open3.capture3(
        { "RAILS_MASTER_KEY" => "test-environment-key", "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s },
        RbConfig.ruby, "-e", script, chdir: directory
      )
      assert status.success?, error
      assert_equal "test-environment-key", output

      FileUtils.mkdir_p(File.join(directory, "config"))
      File.write(File.join(directory, "config/master.key"), "test-file-key\n")
      output, error, status = Open3.capture3(
        { "RAILS_MASTER_KEY" => nil, "BUNDLE_GEMFILE" => Rails.root.join("Gemfile").to_s },
        RbConfig.ruby, "-e", script, chdir: directory
      )
      assert status.success?, error
      assert_equal "test-file-key", output
    end
  end
end
