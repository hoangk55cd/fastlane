require 'spaceship/tunes/application'
require 'spaceship/test_flight/tester'
require_relative 'tester_util'
require_relative 'module'
require_relative 'manager'

module Pilot
  class TesterExporter < Manager
    def export_testers(options)
      UI.user_error!("Export file path is required") unless options[:testers_file_path]

      start(options)
      require 'csv'

      testers = testers()

      file = config[:testers_file_path]

      CSV.open(file, "w") do |csv|
        csv << ['First', 'Last', 'Email', 'Groups', 'Installed Version', 'Install Date']

        testers.each do |tester|
          group_names = tester.groups.join(";") || ""
          latest_install_info = tester.latest_install_info
          install_version = latest_install_info["latestInstalledShortVersion"] || ""
          pretty_date = tester.pretty_install_date || ""

          csv << [tester.first_name, tester.last_name, tester.email, group_names, install_version, pretty_date]
        end

        UI.success("Successfully exported CSV to #{file}")
      end
    end

    def export_testers_json(options)
      UI.user_error!("Export file path is required") unless options[:testers_file_path]

      start(options)
      require 'fileutils'
      require 'json'

      testers = testers()

      file = config[:testers_file_path]

      File.open(file,"w") do |f|
        testers_map = testers.map { |tester| {
          :first_name => tester.first_name,
          :last_name => tester.last_name,
          :email => tester.email,
          :status => tester.status,
          :status_update_date => tester.status_mod_time,
          :groups => tester.groups,
          :install_version => tester.latest_installed_version_number,
          :install_timestamp => tester.latest_installed_date
        }}
        f.write(JSON.pretty_generate(testers_map))

        UI.success("Successfully exported json to #{file}")
      end
    end

    def testers()
      app_filter = (config[:apple_id] || config[:app_identifier])
      if app_filter
        app = Spaceship::Tunes::Application.find(app_filter)

        testers = Spaceship::TestFlight::Tester.all(app_id: app.apple_id)
      else
        testers = Spaceship::TestFlight::Tester.all
      end
    end
  end
end
